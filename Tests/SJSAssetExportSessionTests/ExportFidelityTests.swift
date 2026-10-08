//
//  ExportFidelityTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2026-10-07.
//

import AVFoundation
import SJSAssetExportSession
import Testing

/// What an export keeps from its source. Several of these only differ on iOS, so they're worth
/// running on a device or simulator as well as on macOS.
final class ExportFidelityTests: BaseTests {
    @Test func test_hdr_source_exports_10_bit() async throws {
        let sourceURL = resourceURL(named: "test-4k-hdr-hevc-30fps.mov")
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            timeRange: CMTimeRange(start: .zero, duration: .seconds(1)),
            video: .codec(.hevc, width: 1280, height: 720).color(.hdr),
            to: destinationURL.url,
            as: .mp4
        )

        #expect(try await bitsPerComponent(of: destinationURL.url) == 10)
    }

    @Test func test_sdr_export_stays_8_bit() async throws {
        let sourceURL = resourceURL(named: "test-4k-hdr-hevc-30fps.mov")
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            timeRange: CMTimeRange(start: .zero, duration: .seconds(1)),
            video: .codec(.hevc, width: 1280, height: 720).color(.sdr),
            to: destinationURL.url,
            as: .mp4
        )

        #expect(try await bitsPerComponent(of: destinationURL.url) == 8)
    }

    // MARK: - Helpers

    private func bitsPerComponent(of url: URL) async throws -> Int {
        let track = try #require(try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first)
        let format = try #require(try await track.load(.formatDescriptions).first)
        let bits = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_BitsPerComponent)
        return (bits as? NSNumber)?.intValue ?? 8
    }
}
