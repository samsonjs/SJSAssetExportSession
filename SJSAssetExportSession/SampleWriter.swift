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

    private let queue = DispatchSerialQueue(
        label: "SJSAssetExportSession.SampleWriter",
        autoreleaseFrequency: .workItem,
        target: .global()
    )

    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

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

    private lazy var progressStream: AsyncStream<Float> = AsyncStream { continuation in
        progressContinuation = continuation
    }

    private var progressContinuation: AsyncStream<Float>.Continuation?

    init(
        asset: sending AVAsset,
        timeRange: CMTimeRange,
        audioMix: AVAudioMix?,
        audioOutputSettings: sending [String: (any Sendable)],
        videoComposition: AVVideoComposition,
        videoOutputSettings: sending [String: (any Sendable)],
        optimizeForNetworkUse: Bool,
        outputURL: URL,
        fileType: AVFileType
    ) async throws {
        let duration =
        if timeRange.duration.isValid && !timeRange.duration.isPositiveInfinity {
            timeRange.duration
        } else {
            try await asset.load(.duration)
        }

        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = timeRange

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
        writer.shouldOptimizeForNetworkUse = optimizeForNetworkUse
        guard writer.canApply(outputSettings: videoOutputSettings, forMediaType: .video) else {
            throw Error.setupFailure(reason: "Cannot apply video output settings")
        }

        let audioTracks = try await asset.sendTracks(withMediaType: .audio)
        let videoTracks = try await asset.sendTracks(withMediaType: .video)

        self.audioMix = audioMix
        self.audioOutputSettings = audioOutputSettings
        self.videoComposition = videoComposition
        self.videoOutputSettings = videoOutputSettings
        self.reader = reader
        self.writer = writer
        self.duration = duration
        self.timeRange = timeRange

        try setUpAudio(audioTracks: audioTracks)
        try setUpVideo(videoTracks: videoTracks)
    }

    func writeSamples() async throws {
        progressContinuation?.yield(0)

        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: timeRange.start)

        await encodeAudioTracks()
        await encodeVideoTracks()

        if reader.status == .cancelled || writer.status == .cancelled {
            throw CancellationError()
        } else if writer.status == .failed {
            reader.cancelReading()
            throw Error.writeFailure(writer.error)
        } else if reader.status == .failed {
            writer.cancelWriting()
            throw Error.readFailure(reader.error)
        } else {
            await withCheckedContinuation { continuation in
                writer.finishWriting {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func setUpAudio(audioTracks: [AVAssetTrack]) throws {
        guard !audioTracks.isEmpty else { return }

        let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
        audioOutput.alwaysCopiesSampleData = false
        audioOutput.audioMix = audioMix
        guard reader.canAdd(audioOutput) else {
            throw Error.setupFailure(reason: "Can't add audio output to reader")
        }
        reader.add(audioOutput)
        self.audioOutput = audioOutput

        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
        audioInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(audioInput) else {
            throw Error.setupFailure(reason: "Can't add audio input to writer")
        }
        writer.add(audioInput)
        self.audioInput = audioInput
    }

    private func setUpVideo(videoTracks: [AVAssetTrack]) throws {
        guard !videoTracks.isEmpty else {
            throw Error.setupFailure(reason: "No video tracks")
        }

        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: videoTracks,
            videoSettings: nil
        )
        videoOutput.alwaysCopiesSampleData = false
        videoOutput.videoComposition = videoComposition
        guard reader.canAdd(videoOutput) else {
            throw Error.setupFailure(reason: "Can't add video output to reader")
        }
        reader.add(videoOutput)
        self.videoOutput = videoOutput

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else {
            throw Error.setupFailure(reason: "Can't add video input to writer")
        }
        writer.add(videoInput)
        self.videoInput = videoInput
    }

    private func writeReadySamples(output: AVAssetReaderOutput, input: AVAssetWriterInput) -> Bool {
        while input.isReadyForMoreMediaData {
            guard reader.status == .reading && writer.status == .writing,
                  let sampleBuffer = output.copyNextSampleBuffer() else {
                input.markAsFinished()
                log.debug("Finished encoding ready audio samples from \(output)")
                return false
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
        log.debug("Completed encoding ready audio samples, more to come...")
        return true
    }

    private func encodeAudioTracks() async {
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
}
