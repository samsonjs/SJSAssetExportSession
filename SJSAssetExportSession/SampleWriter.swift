//
//  SampleWriter.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-03.
//

import AVFoundation.AVAsset
import OSLog

private let log = Logger(subsystem: "SJSAssetExportSession", category: "SampleWriter")

private extension AVAsset {
    func sendTracks(withMediaType mediaType: AVMediaType) async throws -> sending [AVAssetTrack] {
        try await loadTracks(withMediaType: mediaType)
    }
}

actor SampleWriter {
    typealias Error = ExportSession.Error

    // MARK: - Actor executor

    private let queue = DispatchSerialQueue(
        label: "SJSAssetExportSession.SampleWriter",
        autoreleaseFrequency: .workItem,
        target: .global()
    )

    // Execute this actor on the same queue we use to request media data so we can use
    // `assumeIsolated` to ensure that we
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    lazy var progressStream: AsyncStream<Float> = AsyncStream { continuation in
        progressContinuation = continuation
    }
    private var progressContinuation: AsyncStream<Float>.Continuation?

    private let audioMix: AVAudioMix?
    private let audioOutputSettings: [String: (any Sendable)]
    private let videoComposition: AVVideoComposition?
    private let videoOutputSettings: [String: (any Sendable)]
    private let reader: AVAssetReader
    private let writer: AVAssetWriter
    private let duration: CMTime
    private let timeRange: CMTimeRange
    private var audioOutput: AVAssetReaderAudioMixOutput?
    private var audioInput: AVAssetWriterInput?
    private var videoOutput: AVAssetReaderVideoCompositionOutput?
    private var videoInput: AVAssetWriterInput?

    init(
        asset: sending AVAsset,
        audioMix: AVAudioMix?,
        audioOutputSettings: sending [String: (any Sendable)],
        videoComposition: AVVideoComposition,
        videoOutputSettings: sending [String: (any Sendable)],
        timeRange: CMTimeRange? = nil,
        optimizeForNetworkUse: Bool = false,
        outputURL: URL,
        fileType: AVFileType
    ) async throws {
        let duration =
        if let timeRange { timeRange.duration } else { try await asset.load(.duration) }
        let reader = try AVAssetReader(asset: asset)
        if let timeRange {
            reader.timeRange = timeRange
        }
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
        writer.shouldOptimizeForNetworkUse = optimizeForNetworkUse

        let audioTracks = try await asset.sendTracks(withMediaType: .audio)
        try Self.validateAudio(tracks: audioTracks, outputSettings: audioOutputSettings, writer: writer)
        let videoTracks = try await asset.sendTracks(withMediaType: .video)
        try Self.validateVideo(tracks: videoTracks, outputSettings: videoOutputSettings, writer: writer)
        Self.warnAboutMismatchedVideoDimensions(
            renderSize: videoComposition.renderSize,
            settings: videoOutputSettings
        )

        self.audioMix = audioMix
        self.audioOutputSettings = audioOutputSettings
        self.videoComposition = videoComposition
        self.videoOutputSettings = videoOutputSettings
        self.reader = reader
        self.writer = writer
        self.duration = duration
        self.timeRange = timeRange ?? CMTimeRange(start: .zero, duration: duration)

        try setUpAudio(audioTracks: audioTracks)
        try setUpVideo(videoTracks: videoTracks)
    }

    func writeSamples() async throws {
        progressContinuation?.yield(0.0)

        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: timeRange.start)

        await encodeVideoTracks()
        await encodeAudioTracks()

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
        progressContinuation?.finish()

        // Make sure the last progress value is yielded before returning.
        await Task.yield()
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

    // MARK: - Encoding

    private func encodeAudioTracks() async {
        // Don't do anything when we have no audio to encode.
        guard audioInput != nil, audioOutput != nil else { return }

        return await withCheckedContinuation { continuation in
            self.audioInput!.requestMediaDataWhenReady(on: queue) {
                let hasMoreSamples = self.assumeIsolated { _self in
                    _self.writeReadySamples(output: _self.audioOutput!, input: _self.audioInput!)
                }
                if !hasMoreSamples {
                    continuation.resume()
                }
            }
        }
    }

    private func encodeVideoTracks() async {
        return await withCheckedContinuation { continuation in
            self.videoInput!.requestMediaDataWhenReady(on: queue) {
                let hasMoreSamples = self.assumeIsolated { _self in
                    _self.writeReadySamples(output: _self.videoOutput!, input: _self.videoInput!)
                }
                if !hasMoreSamples {
                    continuation.resume()
                }
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
        tracks: [AVAssetTrack],
        outputSettings: [String: any Sendable],
        writer: AVAssetWriter
    ) throws {
        guard !tracks.isEmpty else { return } // Audio is optional so this isn't a failure.
        guard !outputSettings.isEmpty else { throw Error.setupFailure(.audioSettingsEmpty) }
        guard writer.canApply(outputSettings: outputSettings, forMediaType: .audio) else {
            throw Error.setupFailure(.audioSettingsInvalid)
        }
    }

    private static func validateVideo(
        tracks: [AVAssetTrack],
        outputSettings: [String: any Sendable],
        writer: AVAssetWriter
    ) throws {
        guard !tracks.isEmpty else { throw Error.setupFailure(.videoTracksEmpty) }
        guard !outputSettings.isEmpty else { throw Error.setupFailure(.videoSettingsEmpty) }
        guard writer.canApply(outputSettings: outputSettings, forMediaType: .video) else {
            throw Error.setupFailure(.videoSettingsInvalid)
        }
    }

    private static func warnAboutMismatchedVideoDimensions(
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
