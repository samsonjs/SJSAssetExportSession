//
//  SJSAssetExportSessionTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2024-06-29.
//

import AVFoundation
@testable import SJSAssetExportSession
import Testing

final class ExportSessionTests {
    private let defaultAudioSettings: [String: any Sendable] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: NSNumber(value: 2),
        AVSampleRateKey: NSNumber(value: 44_100.0),
    ]

    private func defaultVideoSettings(size: CGSize, bitrate: Int? = nil) -> [String: any Sendable] {
        let compressionProperties: [String: any Sendable] =
        if let bitrate { [AVVideoAverageBitRateKey: NSNumber(value: bitrate)] } else { [:] }
        return [
            AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
            AVVideoWidthKey: NSNumber(value: Int(size.width)),
            AVVideoHeightKey: NSNumber(value: Int(size.height)),
            AVVideoCompressionPropertiesKey: compressionProperties,
        ]
    }

    private func resourceURL(named name: String, withExtension ext: String) -> URL {
        Bundle(for: Self.self).url(forResource: name, withExtension: ext)!
    }

    private func makeAsset(url: URL) -> sending AVAsset {
        AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true,
        ])
    }

    private func makeFilename(function: String = #function) -> String {
        let timestamp = Int(Date.now.timeIntervalSince1970)
        let f = function.replacing(/[\(\)]/, with: { _ in "" })
        let filename = "\(Self.self)_\(f)_\(timestamp).mp4"
        return filename
    }

    private func makeTemporaryURL(function: String = #function) -> AutoDestructingURL {
        let filename = makeFilename(function: function)
        let url = URL.temporaryDirectory.appending(component: filename)
        return AutoDestructingURL(url: url)
    }

    private func makeVideoComposition(
        assetURL: URL,
        size: CGSize? = nil,
        fps: Int? = nil,
        removeHDR: Bool = false
    ) async throws -> sending AVMutableVideoComposition {
        let asset = makeAsset(url: assetURL)
        let videoComposition = try await AVMutableVideoComposition.videoComposition(
            withPropertiesOf: asset
        )
        if let size {
            videoComposition.renderSize = size
        }
        if let fps {
            let seconds = 1.0 / TimeInterval(fps)
            videoComposition.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
            videoComposition.frameDuration = CMTime(seconds: seconds, preferredTimescale: 600)
        }
        if removeHDR {
            videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
            videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
            videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        }
        return videoComposition
    }

    @Test func test_export_720p_h264_24fps() async throws {
        let sourceURL = resourceURL(named: "test-4k-hdr-hevc-30fps", withExtension: "mov")
        let sourceAsset = makeAsset(url: sourceURL)
        let size = CGSize(width: 1280, height: 720)
        let duration = CMTime(seconds: 1, preferredTimescale: 600)
        let videoComposition = try await makeVideoComposition(
            assetURL: sourceURL,
            size: size,
            fps: 24,
            removeHDR: true
        )
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: sourceAsset,
            audioMix: nil,
            audioOutputSettings: defaultAudioSettings,
            videoComposition: videoComposition,
            videoOutputSettings: defaultVideoSettings(size: size, bitrate: 1_000_000),
            timeRange: CMTimeRange(start: .zero, duration: duration),
            to: destinationURL.url,
            as: .mp4
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        #expect(try await exportedAsset.load(.duration) == duration)
        // Audio
        try #require(try await exportedAsset.sendTracks(withMediaType: .audio).count == 1)
        let audioTrack = try #require(await exportedAsset.sendTracks(withMediaType: .audio).first)
        let audioFormat = try #require(await audioTrack.load(.formatDescriptions).first)
        #expect(audioFormat.mediaType == .audio)
        #expect(audioFormat.mediaSubType == .mpeg4AAC)
        #expect(audioFormat.audioChannelLayout?.numberOfChannels == 2)
        #expect(audioFormat.audioStreamBasicDescription?.mSampleRate == 44_100)
        // Video
        try #require(await exportedAsset.sendTracks(withMediaType: .video).count == 1)
        let videoTrack = try #require(await exportedAsset.sendTracks(withMediaType: .video).first)
        #expect(try await videoTrack.load(.naturalSize) == CGSize(width: 1280, height: 720))
        #expect(try await videoTrack.load(.nominalFrameRate) == 24.0)
        #expect(try await videoTrack.load(.estimatedDataRate) == 1_036_128)
        let videoFormat = try #require(await videoTrack.load(.formatDescriptions).first)
        #expect(videoFormat.mediaType == .video)
        #expect(videoFormat.mediaSubType == .h264)
        #expect(videoFormat.extensions[.colorPrimaries] == .colorPrimaries(.itu_R_709_2))
        #expect(videoFormat.extensions[.transferFunction] == .transferFunction(.itu_R_709_2))
        #expect(videoFormat.extensions[.yCbCrMatrix] == .yCbCrMatrix(.itu_R_709_2))
    }

    @Test func test_export_default_timerange() async throws {
        let sourceURL = resourceURL(named: "test-720p-h264-24fps", withExtension: "mov")
        let sourceAsset = makeAsset(url: sourceURL)
        let originalDuration = try await sourceAsset.load(.duration)
        let videoComposition = try await makeVideoComposition(assetURL: sourceURL)
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: sourceAsset,
            audioMix: nil,
            audioOutputSettings: defaultAudioSettings,
            videoComposition: videoComposition,
            videoOutputSettings: defaultVideoSettings(size: videoComposition.renderSize),
            to: destinationURL.url,
            as: .mov
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        #expect(try await exportedAsset.load(.duration) == originalDuration)
    }

    @Test func test_export_progress() async throws {
        let sourceURL = resourceURL(named: "test-720p-h264-24fps", withExtension: "mov")
        let sourceAsset = makeAsset(url: sourceURL)
        let videoComposition = try await makeVideoComposition(assetURL: sourceURL)
        let size = videoComposition.renderSize
        let progressValues = SendableWrapper<[Float]>([])

        let subject = ExportSession()
        Task {
            for await progress in subject.progressStream {
                progressValues.value.append(progress)
            }
        }
        try await subject.export(
            asset: sourceAsset,
            audioMix: nil,
            audioOutputSettings: defaultAudioSettings,
            videoComposition: videoComposition,
            videoOutputSettings: defaultVideoSettings(size: size),
            to: makeTemporaryURL().url,
            as: .mov
        )

        #expect(progressValues.value.count > 2, "There should be intermediate progress updates")
        #expect(progressValues.value.first == 0.0)
        #expect(progressValues.value.last == 1.0)
    }

    @Test func test_export_works_with_no_audio() async throws {
        let sourceURL = resourceURL(named: "test-no-audio", withExtension: "mp4")
        let sourceAsset = makeAsset(url: sourceURL)
        let videoComposition = try await makeVideoComposition(assetURL: sourceURL)

        let subject = ExportSession()
        try await subject.export(
            asset: sourceAsset,
            audioMix: nil,
            audioOutputSettings: [:],
            videoComposition: videoComposition,
            videoOutputSettings: defaultVideoSettings(size: videoComposition.renderSize),
            to: makeTemporaryURL().url,
            as: .mov
        )
    }

    @Test func test_export_throws_with_empty_audio_settings() async throws {
        try await #require(throws: ExportSession.Error.setupFailure(.audioSettingsEmpty)) {
            let sourceURL = resourceURL(named: "test-720p-h264-24fps", withExtension: "mov")
            let sourceAsset = makeAsset(url: sourceURL)
            let videoComposition = try await makeVideoComposition(assetURL: sourceURL)

            let subject = ExportSession()
            try await subject.export(
                asset: sourceAsset,
                audioMix: nil,
                audioOutputSettings: [:],
                videoComposition: videoComposition,
                videoOutputSettings: defaultVideoSettings(size: videoComposition.renderSize),
                to: makeTemporaryURL().url,
                as: .mov
            )
        }
    }

    @Test func test_export_throws_with_invalid_audio_settings() async throws {
        try await #require(throws: ExportSession.Error.setupFailure(.audioSettingsInvalid)) {
            let sourceURL = resourceURL(named: "test-720p-h264-24fps", withExtension: "mov")
            let sourceAsset = makeAsset(url: sourceURL)
            let videoComposition = try await makeVideoComposition(assetURL: sourceURL)

            let subject = ExportSession()
            try await subject.export(
                asset: sourceAsset,
                audioMix: nil,
                audioOutputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: NSNumber(value: -1), // invalid number of channels
                ],
                videoComposition: videoComposition,
                videoOutputSettings: defaultVideoSettings(size: videoComposition.renderSize),
                to: makeTemporaryURL().url,
                as: .mov
            )
        }
    }

    @Test func test_export_throws_with_empty_video_settings() async throws {
        try await #require(throws: ExportSession.Error.setupFailure(.videoSettingsEmpty)) {
            let sourceURL = resourceURL(named: "test-720p-h264-24fps", withExtension: "mov")
            let sourceAsset = makeAsset(url: sourceURL)
            let videoComposition = try await makeVideoComposition(assetURL: sourceURL)

            let subject = ExportSession()
            try await subject.export(
                asset: sourceAsset,
                audioMix: nil,
                audioOutputSettings: defaultAudioSettings,
                videoComposition: videoComposition,
                videoOutputSettings: [:],
                to: makeTemporaryURL().url,
                as: .mov
            )
        }
    }

    @Test func test_export_throws_with_invalid_video_settings() async throws {
        try await #require(throws: ExportSession.Error.setupFailure(.videoSettingsInvalid)) {
            let sourceURL = resourceURL(named: "test-720p-h264-24fps", withExtension: "mov")
            let sourceAsset = makeAsset(url: sourceURL)
            let videoComposition = try await makeVideoComposition(assetURL: sourceURL)
            let size = videoComposition.renderSize

            let subject = ExportSession()
            try await subject.export(
                asset: sourceAsset,
                audioMix: nil,
                audioOutputSettings: defaultAudioSettings,
                videoComposition: videoComposition,
                videoOutputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
                    // missing video width
                    AVVideoHeightKey: NSNumber(value: Int(size.height)),
                ],
                to: makeTemporaryURL().url,
                as: .mov
            )
        }
    }

    @Test func test_export_throws_with_no_video() async throws {
        try await #require(throws: ExportSession.Error.setupFailure(.videoTracksEmpty)) {
            let sourceURL = resourceURL(named: "test-no-video", withExtension: "m4a")
            let sourceAsset = makeAsset(url: sourceURL)
            let videoComposition = try await makeVideoComposition(assetURL: sourceURL)
            let size = videoComposition.renderSize

            let subject = ExportSession()
            try await subject.export(
                asset: sourceAsset,
                audioMix: nil,
                audioOutputSettings: defaultAudioSettings,
                videoComposition: videoComposition,
                videoOutputSettings: defaultVideoSettings(size: size),
                to: makeTemporaryURL().url,
                as: .mov
            )
        }
    }
}
