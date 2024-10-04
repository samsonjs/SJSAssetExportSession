//
//  SampleWriter.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-03.
//

import AVFoundation.AVAsset
import OSLog

private let log = Logger(subsystem: "SJSAssetExportSession", category: "SampleWriter")

actor SampleWriter {
    typealias Error = ExportSession.Error

    // MARK: - Actor executor

    private let queue = DispatchSerialQueue(
        label: "SJSAssetExportSession.SampleWriter",
        qos: .userInitiated
    )

    // Execute this actor on the same queue we use to request media data so we can use
    // `assumeIsolated` to ensure that we serialize access to our state without creating
    // tasks and doing lots of needless context-switching.
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    lazy var progressStream: AsyncStream<Float> = AsyncStream { continuation in
        progressContinuation = continuation
    }
    private var progressContinuation: AsyncStream<Float>.Continuation?

    private let audioOutputSettings: [String: any Sendable]
    private let audioMix: AVAudioMix?
    private let videoOutputSettings: [String: any Sendable]
    private let videoComposition: AVVideoComposition?
    private let reader: AVAssetReader
    private let writer: AVAssetWriter
    private let duration: CMTime
    private let timeRange: CMTimeRange
    private var audioOutput: AVAssetReaderAudioMixOutput?
    private var audioInput: AVAssetWriterInput?
    private var videoOutput: AVAssetReaderVideoCompositionOutput?
    private var videoInput: AVAssetWriterInput?
    private var isCancelled = false

    nonisolated init(
        asset: sending AVAsset,
        audioOutputSettings: sending [String: any Sendable],
        audioMix: sending AVAudioMix?,
        videoOutputSettings: sending [String: any Sendable],
        videoComposition: sending AVVideoComposition,
        timeRange: CMTimeRange? = nil,
        optimizeForNetworkUse: Bool = false,
        metadata: [AVMetadataItem] = [],
        outputURL: URL,
        fileType: AVFileType
    ) async throws {
        precondition(!videoOutputSettings.isEmpty)

        let duration = if let timeRange {
            timeRange.duration
        } else {
            try await asset.load(.duration)
        }
        let reader = try AVAssetReader(asset: asset)
        if let timeRange {
            reader.timeRange = timeRange
        }
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
        writer.shouldOptimizeForNetworkUse = optimizeForNetworkUse
        writer.metadata = metadata

        // Filter out disabled tracks to avoid problems encoding spatial audio. Ideally this would
        // preserve track groups and make that all configurable.
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            .filterAsync { try await $0.load(.isEnabled) }
        // Audio is optional so only validate output settings when it's applicable.
        if !audioTracks.isEmpty {
            try Self.validateAudio(outputSettings: audioOutputSettings, writer: writer)
        }
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
            .filterAsync { try await $0.load(.isEnabled) }
        guard !videoTracks.isEmpty else { throw Error.setupFailure(.videoTracksEmpty) }
        try Self.validateVideo(outputSettings: videoOutputSettings, writer: writer)
        Self.warnAboutMismatchedVideoSize(
            renderSize: videoComposition.renderSize,
            settings: videoOutputSettings
        )

        self.audioOutputSettings = audioOutputSettings
        self.audioMix = audioMix
        self.videoOutputSettings = videoOutputSettings
        self.videoComposition = videoComposition
        self.reader = reader
        self.writer = writer
        self.duration = duration
        self.timeRange = timeRange ?? CMTimeRange(start: .zero, duration: duration)

        try await setUpAudio(audioTracks: audioTracks)
        try await setUpVideo(videoTracks: videoTracks)
    }

    func writeSamples() async throws {
        try Task.checkCancellation()

        progressContinuation?.yield(0.0)

        writer.startWriting()
        writer.startSession(atSourceTime: timeRange.start)
        reader.startReading()
        try Task.checkCancellation()

        await encodeAudioTracks()
        try Task.checkCancellation()

        await encodeVideoTracks()
        try Task.checkCancellation()

        guard reader.status != .cancelled && writer.status != .cancelled else {
            throw CancellationError()
        }
        guard writer.status != .failed else {
            reader.cancelReading()
            throw Error.writeFailure(writer.error)
        }
        guard reader.status != .failed else {
            writer.cancelWriting()
            throw Error.readFailure(reader.error)
        }

        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume(returning: ())
            }
        }

        progressContinuation?.yield(1.0)

        // Make sure the last progress value is yielded before returning.
        await Task.yield()
        await withCheckedContinuation { continuation in
            progressContinuation?.onTermination = { _ in
                continuation.resume(returning: ())
            }
            progressContinuation?.finish()
        }
    }

    // MARK: - Setup

    private func setUpAudio(audioTracks: [AVAssetTrack]) throws {
        guard !audioTracks.isEmpty else { return }

        let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
        audioOutput.alwaysCopiesSampleData = false
        audioOutput.audioMix = audioMix
        guard reader.canAdd(audioOutput) else {
            throw Error.setupFailure(.cannotAddAudioOutput)
        }
        reader.add(audioOutput)
        self.audioOutput = audioOutput

        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
        audioInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(audioInput) else {
            throw Error.setupFailure(.cannotAddAudioInput)
        }
        writer.add(audioInput)
        self.audioInput = audioInput
    }

    private func setUpVideo(videoTracks: [AVAssetTrack]) throws {
        precondition(!videoTracks.isEmpty, "Video tracks must be provided")

        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: videoTracks,
            videoSettings: nil
        )
        videoOutput.alwaysCopiesSampleData = false
        videoOutput.videoComposition = videoComposition
        guard reader.canAdd(videoOutput) else {
            throw Error.setupFailure(.cannotAddVideoOutput)
        }
        reader.add(videoOutput)
        self.videoOutput = videoOutput

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else {
            throw Error.setupFailure(.cannotAddVideoInput)
        }
        writer.add(videoInput)
        self.videoInput = videoInput
    }

    func cancel() async {
        isCancelled = true
    }

    // MARK: - Encoding

    private func encodeAudioTracks() async {
        // Don't do anything when we have no audio to encode.
        guard audioInput != nil, audioOutput != nil else { return }

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.audioInput!.requestMediaDataWhenReady(on: queue) {
                    self.assumeIsolated { _self in
                        guard !_self.isCancelled else {
                            log.debug("Cancelled while encoding audio")
                            _self.reader.cancelReading()
                            _self.writer.cancelWriting()
                            continuation.resume()
                            return
                        }

                        let hasMoreSamples = _self.writeReadySamples(
                            output: _self.audioOutput!,
                            input: _self.audioInput!
                        )
                        if !hasMoreSamples {
                            log.debug("Finished encoding audio")
                            continuation.resume()
                        }
                    }
                }
            }
        } onCancel: {
            log.debug("Task cancelled while encoding audio")
            Task {
                await self.cancel()
            }
        }
    }

    private func encodeVideoTracks() async {
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.videoInput!.requestMediaDataWhenReady(on: queue) {
                    #warning("FIXME: why is this broken on macOS?!")
                    self.assumeIsolated { _self in
                        guard !_self.isCancelled else {
                            log.debug("Cancelled while encoding video")
                            _self.reader.cancelReading()
                            _self.writer.cancelWriting()
                            continuation.resume()
                            return
                        }

                        let hasMoreSamples = _self.writeReadySamples(
                            output: _self.videoOutput!,
                            input: _self.videoInput!
                        )
                        if !hasMoreSamples {
                            log.debug("Finished encoding video")
                            continuation.resume()
                        }
                    }
                }
            }
        } onCancel: {
            log.debug("Task cancelled while encoding video")
            Task {
                await self.cancel()
            }
        }
    }

    private func writeReadySamples(output: AVAssetReaderOutput, input: AVAssetWriterInput) -> Bool {
        while input.isReadyForMoreMediaData {
            guard reader.status == .reading && writer.status == .writing,
                  let sampleBuffer = output.copyNextSampleBuffer() else {
                input.markAsFinished()
                return false
            }

            // Only yield progress values for video. Audio is insignificant in comparison.
            if output == videoOutput {
                let samplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) - timeRange.start
                let progress = Float(samplePresentationTime.seconds / duration.seconds)
                progressContinuation?.yield(progress)
            }

            guard input.append(sampleBuffer) else {
                log.error("""
                    Failed to append audio sample buffer \(String(describing: sampleBuffer)) to
                    input \(input.debugDescription)
                """)
                return false
            }
        }

        // Everything was appended successfully, return true indicating there's more to do.
        return true
    }

    // MARK: Input validation

    private static func validateAudio(
        outputSettings: [String: any Sendable],
        writer: AVAssetWriter
    ) throws {
        guard !outputSettings.isEmpty else { throw Error.setupFailure(.audioSettingsEmpty) }
        guard writer.canApply(outputSettings: outputSettings, forMediaType: .audio) else {
            throw Error.setupFailure(.audioSettingsInvalid)
        }
    }

    private static func validateVideo(
        outputSettings: [String: any Sendable],
        writer: AVAssetWriter
    ) throws {
        guard writer.canApply(outputSettings: outputSettings, forMediaType: .video) else {
            throw Error.setupFailure(.videoSettingsInvalid)
        }
    }

    private static func warnAboutMismatchedVideoSize(
        renderSize: CGSize,
        settings: [String: any Sendable]
    ) {
        guard let settingsWidth = (settings[AVVideoWidthKey] as? NSNumber)?.intValue,
              let settingsHeight = (settings[AVVideoHeightKey] as? NSNumber)?.intValue
        else { return }

        let renderWidth = Int(renderSize.width)
        let renderHeight = Int(renderSize.height)
        if renderWidth != settingsWidth || renderHeight != settingsHeight {
            log.warning("Video composition's render size (\(renderWidth)ｘ\(renderHeight)) will be overriden by video output settings (\(settingsWidth)ｘ\(settingsHeight))")
        }
    }
}
