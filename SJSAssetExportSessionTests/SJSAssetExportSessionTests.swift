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
    @Test func test_encode_h264_720p_30fps() async throws {
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
        videoComposition.renderScale = 1
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
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
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel as String,
                ] as [String: any Sendable],
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
                ],
            ],
            timeRange: CMTimeRange(start: .zero, duration: duration),
            to: destinationURL,
            as: .mp4
        )

        let asset = AVURLAsset(url: destinationURL)
        #expect(try await asset.load(.duration) == duration)
        try #require(await asset.loadTracks(withMediaType: .video).count == 1)
        let videoTrack = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(try await videoTrack.load(.naturalSize) == size)
        try #require(try await asset.loadTracks(withMediaType: .audio).count == 1)
    }
}
