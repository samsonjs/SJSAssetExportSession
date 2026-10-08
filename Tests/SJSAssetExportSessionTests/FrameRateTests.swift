//
//  FrameRateTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2026-10-07.
//

import AVFoundation
import SJSAssetExportSession
import Testing

/// A composition that times its frames with `frameDuration` gets exactly that rate, whatever
/// rate the source has.
final class FrameRateTests: BaseTests {
    @Test func test_sparse_source_fills_the_target_frame_rate() async throws {
        // Six frames at 2 fps: three seconds.
        let video = try await TestVideo.make(fps: 2, frameCount: 6)
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            video: .codec(.h264, size: TestVideo.size).fps(30),
            to: destinationURL.url,
            as: .mp4
        )

        #expect(try await countFrames(of: destinationURL.url) == 90)
        let duration = try await AVURLAsset(url: destinationURL.url).load(.duration)
        #expect(abs(duration.seconds - 3) < 0.05)
    }

    @Test func test_draw_frame_is_called_for_every_added_frame() async throws {
        let video = try await TestVideo.make(fps: 2, frameCount: 6)
        let times = SendableWrapper<[CMTime]>([])

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            video: .codec(.h264, size: TestVideo.size).fps(30),
            drawFrame: { frame in times.value.append(frame.presentationTime) },
            to: makeTemporaryURL().url,
            as: .mp4
        )

        #expect(times.value.count == 90)
        let expected = (0 ..< 90).map { CMTime(value: CMTimeValue($0), timescale: 30) }
        #expect(times.value.map(\.seconds) == expected.map(\.seconds))
    }

    @Test func test_overlay_moves_on_every_added_frame() async throws {
        let video = try await TestVideo.make(fps: 2, frameCount: 2)
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            video: .codec(.h264, size: TestVideo.size).fps(10),
            drawFrame: { frame in
                // A square sliding right 40 points a second.
                let x = 40 * frame.presentationTime.seconds
                fillWhite(CGRect(x: x, y: 160, width: 20, height: 20), in: frame.pixelBuffer)
            },
            to: destinationURL.url,
            as: .mp4
        )

        // At 0.2 s the square starts at x = 8 and at 0.4 s at x = 16. Both are shown by the
        // first source frame, which lasts half a second.
        let early = try await DecodedFrame.at(CMTime(value: 2, timescale: 10), in: destinationURL.url)
        let later = try await DecodedFrame.at(CMTime(value: 4, timescale: 10), in: destinationURL.url)
        #expect(early.colour(at: CGPoint(x: 10, y: 170)) == .white)
        #expect(later.colour(at: CGPoint(x: 10, y: 170)) == .blue)
        #expect(later.colour(at: CGPoint(x: 30, y: 170)) == .white)
    }

    @Test func test_repeated_frames_keep_the_frame_guarantees() async throws {
        let video = try await TestVideo.make(fps: 2, frameCount: 2)
        let frames = SendableWrapper<[RepeatFacts]>([])

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            video: .codec(.h264, size: TestVideo.size).fps(10).color(.sdr),
            drawFrame: { frame in frames.value.append(RepeatFacts(frame)) },
            to: makeTemporaryURL().url,
            as: .mp4
        )

        #expect(frames.value.count == 10)
        for facts in frames.value {
            #expect(facts.pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
            #expect(facts.isIOSurfaceBacked)
            #expect(facts.isMetalCompatible)
            #expect(facts.hasColourAttachments)
        }
    }

    @Test func test_dense_source_drops_to_the_target_frame_rate() async throws {
        // Thirty frames at 60 fps: half a second.
        let video = try await TestVideo.make(fps: 60, frameCount: 30)
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            video: .codec(.h264, size: TestVideo.size).fps(30),
            to: destinationURL.url,
            as: .mp4
        )

        #expect(try await countFrames(of: destinationURL.url) == 15)
    }

    @Test func test_source_timing_is_kept_without_a_target_frame_rate() async throws {
        let video = try await TestVideo.make(fps: 2, frameCount: 6)
        let destinationURL = makeTemporaryURL()
        let calls = SendableWrapper(0)

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            video: .codec(.h264, size: TestVideo.size),
            drawFrame: { _ in calls.value += 1 },
            to: destinationURL.url,
            as: .mp4
        )

        #expect(calls.value == 6)
        #expect(try await countFrames(of: destinationURL.url) == 6)
    }

    @Test func test_target_frame_rate_starts_at_the_time_range() async throws {
        let video = try await TestVideo.make(fps: 2, frameCount: 6)
        let times = SendableWrapper<[CMTime]>([])

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            timeRange: CMTimeRange(start: .seconds(1), duration: .seconds(1)),
            video: .codec(.h264, size: TestVideo.size).fps(10),
            drawFrame: { frame in times.value.append(frame.presentationTime) },
            to: makeTemporaryURL().url,
            as: .mp4
        )

        #expect(times.value.count == 10)
        #expect(times.value.first?.seconds == 1)
        #expect(abs((times.value.last?.seconds ?? 0) - 1.9) < 0.001)
    }

    // MARK: - Helpers

    struct RepeatFacts {
        let pixelFormat: OSType
        let isIOSurfaceBacked: Bool
        let hasColourAttachments: Bool
        let isMetalCompatible: Bool

        init(_ frame: VideoFrame) {
            let buffer = frame.pixelBuffer
            pixelFormat = CVPixelBufferGetPixelFormatType(buffer)
            isIOSurfaceBacked = CVPixelBufferGetIOSurface(buffer) != nil
            let attachments = CVBufferCopyAttachments(buffer, .shouldPropagate) as? [String: Any] ?? [:]
            hasColourAttachments = attachments[kCVImageBufferYCbCrMatrixKey as String] != nil
            isMetalCompatible = DrawFrameTests.FrameFacts(frame).isMetalCompatible
        }
    }

    private func countFrames(of url: URL) async throws -> Int {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        reader.startReading()
        var count = 0
        while let sample = output.copyNextSampleBuffer() {
            count += CMSampleBufferGetNumSamples(sample)
        }
        return count
    }
}
