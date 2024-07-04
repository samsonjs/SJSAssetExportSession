//
//  SampleWriter.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-03.
//

import AVFoundation.AVAsset

private extension AVAsset {
    func sendTracks(withMediaType mediaType: AVMediaType) async throws -> sending [AVAssetTrack] {
        try await loadTracks(withMediaType: mediaType)
    }
}

actor SampleWriter {
    private let queue = DispatchSerialQueue(
        label: "SJSAssetExportSession.SampleWriter",
        autoreleaseFrequency: .workItem,
        target: .global()
    )

    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    let audioTracks: [AVAssetTrack]

    let audioMix: AVAudioMix?

    let audioOutputSettings: [String: (any Sendable)]

    let videoTracks: [AVAssetTrack]

    let videoComposition: AVVideoComposition?

    let videoOutputSettings: [String: (any Sendable)]

    let reader: AVAssetReader

    let writer: AVAssetWriter

    let duration: CMTime

    let timeRange: CMTimeRange

    private var audioOutput: AVAssetReaderAudioMixOutput?

    private var audioInput: AVAssetWriterInput?

    private var videoOutput: AVAssetReaderVideoCompositionOutput?

    private var videoInput: AVAssetWriterInput?

    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    init(
        asset: sending AVAsset,
        timeRange: CMTimeRange,
        audioMix: AVAudioMix?,
        audioOutputSettings: sending [String: (any Sendable)],
        videoComposition: AVVideoComposition?,
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
            throw ExportSession.Error.setupFailure(reason: "Cannot apply video output settings")
        }

        self.audioTracks = try await asset.sendTracks(withMediaType: .audio)
        self.audioMix = audioMix
        self.audioOutputSettings = audioOutputSettings
        self.videoTracks = try await asset.sendTracks(withMediaType: .video)
        self.videoComposition = videoComposition
        self.videoOutputSettings = videoOutputSettings
        self.reader = reader
        self.writer = writer
        self.duration = duration
        self.timeRange = timeRange
    }

    func writeSamples() async throws {
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: timeRange.start)

        async let audioResult = try encodeAudioTracks(audioTracks)
        async let videoResult = try encodeVideoTracks(videoTracks)
        _ = try await (audioResult, videoResult)

        if reader.status == .cancelled || writer.status == .cancelled {
            throw CancellationError()
        } else if writer.status == .failed {
            reader.cancelReading()
            throw ExportSession.Error.writeFailure(writer.error)
        } else if reader.status == .failed {
            writer.cancelWriting()
            throw ExportSession.Error.readFailure(reader.error)
        } else {
            await withCheckedContinuation { continuation in
                writer.finishWriting {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func encodeAudioTracks(_ audioTracks: [AVAssetTrack]) async throws -> Bool {
        guard !audioTracks.isEmpty else { return false }

        let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
        guard reader.canAdd(audioOutput) else {
            throw ExportSession.Error.setupFailure(reason: "Can't add audio output to reader")
        }
        reader.add(audioOutput)
        self.audioOutput = audioOutput

        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
        guard writer.canAdd(audioInput) else {
            throw ExportSession.Error.setupFailure(reason: "Can't add audio input to writer")
        }
        writer.add(audioInput)
        self.audioInput = audioInput

        return await withCheckedContinuation { continuation in
            self.audioInput?.requestMediaDataWhenReady(on: queue) {
                let hasMoreSamples = self.assumeIsolated { $0.writeReadyAudioSamples() }
                if !hasMoreSamples {
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func writeReadyAudioSamples() -> Bool {
        guard let audioOutput, let audioInput else { return true }

        while audioInput.isReadyForMoreMediaData {
            guard reader.status == .reading && writer.status == .writing,
                  let sampleBuffer = audioOutput.copyNextSampleBuffer() else {
                audioInput.markAsFinished()
                NSLog("Finished encoding ready audio samples from \(audioOutput)")
                return false
            }

            guard audioInput.append(sampleBuffer) else {
                NSLog("Failed to append audio sample buffer \(sampleBuffer) to input \(audioInput)")
                return false
            }
        }

        // Everything was appended successfully, return true indicating there's more to do.
        NSLog("Completed encoding ready audio samples, more to come...")
        return true
    }

    private func encodeVideoTracks(_ videoTracks: [AVAssetTrack]) async throws -> Bool {
        guard !videoTracks.isEmpty else { return false }

        guard let width = videoComposition.map({ Int($0.renderSize.width) })
                ?? (videoOutputSettings[AVVideoWidthKey] as? NSNumber)?.intValue,
              let height = videoComposition.map({ Int($0.renderSize.height) })
                ?? (videoOutputSettings[AVVideoHeightKey] as? NSNumber)?.intValue else {
            throw ExportSession.Error.setupFailure(reason: "Export dimensions must be provided in a video composition or video output settings")
        }

        let videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: nil)
        videoOutput.alwaysCopiesSampleData = false
        videoOutput.videoComposition = videoComposition
        guard reader.canAdd(videoOutput) else {
            throw ExportSession.Error.setupFailure(reason: "Can't add video output to reader")
        }
        reader.add(videoOutput)
        self.videoOutput = videoOutput

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
        guard writer.canAdd(videoInput) else {
            throw ExportSession.Error.setupFailure(reason: "Can't add video input to writer")
        }
        writer.add(videoInput)
        self.videoInput = videoInput

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(integerLiteral: Int(kCVPixelFormatType_32RGBA)),
            kCVPixelBufferWidthKey as String: NSNumber(integerLiteral: width),
            kCVPixelBufferHeightKey as String: NSNumber(integerLiteral: height),
            "IOSurfaceOpenGLESTextureCompatibility": NSNumber(booleanLiteral: true),
            "IOSurfaceOpenGLESFBOCompatibility": NSNumber(booleanLiteral: true),
        ]
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        return await withCheckedContinuation { continuation in
            self.videoInput?.requestMediaDataWhenReady(on: queue) {
                let hasMoreSamples = self.assumeIsolated { $0.writeReadyVideoSamples() }
                if !hasMoreSamples {
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func writeReadyVideoSamples() -> Bool {
        guard let videoOutput, let videoInput, let pixelBufferAdaptor else { return true }

        while videoInput.isReadyForMoreMediaData {
            guard reader.status == .reading && writer.status == .writing,
                  let sampleBuffer = videoOutput.copyNextSampleBuffer() else {
                videoInput.markAsFinished()
                NSLog("Finished encoding ready video samples from \(videoOutput)")
                return false
            }

            let samplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) - timeRange.start
            let progress = Float(samplePresentationTime.seconds / duration.seconds)
#warning("TODO: publish progress to an AsyncStream")

            guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
                NSLog("No pixel buffer pool available on adaptor \(pixelBufferAdaptor)")
                return false
            }
            var toRenderBuffer: CVPixelBuffer?
            let result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &toRenderBuffer)
            var handled = false
            if result == kCVReturnSuccess, let toBuffer = toRenderBuffer {
                handled = pixelBufferAdaptor.append(toBuffer, withPresentationTime: samplePresentationTime)
                if !handled { return false }
            }
            if !handled {
#warning("is this really necessary?! seems like a failure scenario...")
                guard videoInput.append(sampleBuffer) else {
                    NSLog("Failed to append video sample buffer \(sampleBuffer) to input \(videoInput)")
                    return false
                }
            }
        }

        // Everything was appended successfully, return true indicating there's more to do.
        NSLog("Completed encoding ready video samples, more to come...")
        return true
    }

}
