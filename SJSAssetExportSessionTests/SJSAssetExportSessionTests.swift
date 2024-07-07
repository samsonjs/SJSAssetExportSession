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
    @Test func test_export_h264_720p_24fps() async throws {
        let sourceURL = Bundle(for: Self.self).url(forResource: "test", withExtension: "mov")!
        let sourceAsset = AVURLAsset(url: sourceURL)
        let timestamp = Int(Date.now.timeIntervalSince1970)
        let filename = "ExportSessionTests_testEncode_\(timestamp).mp4"
        let destinationURL = URL.temporaryDirectory.appending(component: filename)
        defer { _ = try? FileManager.default.removeItem(at: destinationURL) }
        let size = CGSize(width: 1280, height: 720)
        let duration = CMTime(seconds: 1, preferredTimescale: 600)
        let videoComposition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: sourceAsset)
        videoComposition.renderSize = size
        videoComposition.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
        videoComposition.frameDuration = CMTime(seconds: 1 / 24, preferredTimescale: 600)
        videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
        videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
        videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2

        try await ExportSession.export(
            asset: sourceAsset,
            audioMix: nil,
            audioOutputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: NSNumber(value: 2),
                AVSampleRateKey: NSNumber(value: 44_100.0),
            ],
            videoComposition: videoComposition,
            videoOutputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
                AVVideoWidthKey: NSNumber(value: Int(size.width)),
                AVVideoHeightKey: NSNumber(value: Int(size.height)),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: NSNumber(value: 1_000_000),
                ] as [String: any Sendable],
            ],
            timeRange: CMTimeRange(start: .zero, duration: duration),
            to: destinationURL,
            as: .mp4
        )

        let asset = AVURLAsset(url: destinationURL)
        #expect(try await asset.load(.duration) == duration)
        // Audio
        try #require(try await asset.loadTracks(withMediaType: .audio).count == 1)
        let audioTrack = try #require(await asset.loadTracks(withMediaType: .audio).first)
        let audioFormat = try #require(await audioTrack.load(.formatDescriptions).first)
        #expect(audioFormat.mediaType == .audio)
        #expect(audioFormat.mediaSubType == .mpeg4AAC)
        #expect(audioFormat.audioChannelLayout?.numberOfChannels == 2)
        #expect(audioFormat.audioStreamBasicDescription?.mSampleRate == 44_100)
        // Video
        try #require(await asset.loadTracks(withMediaType: .video).count == 1)
        let videoTrack = try #require(await asset.loadTracks(withMediaType: .video).first)
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
}
