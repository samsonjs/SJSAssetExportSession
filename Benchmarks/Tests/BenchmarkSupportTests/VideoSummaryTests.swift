import BenchmarkSupport
import Foundation
import Testing

struct VideoSummaryTests {
    @Test func test_summarizes_a_video_file() async throws {
        let url = BenchmarkMedia(environment: [:]).fixture("test-720p-h264-24fps.mov")

        let summary = try await VideoSummary.of(url)

        #expect(summary.frameCount == 24)
        #expect(abs(summary.duration - 1.0) < 0.01)
    }

    @Test func test_expected_frame_count_follows_a_new_frame_rate() {
        let source = VideoSummary(duration: 5.5, frameCount: 330)

        #expect(source.converted(toFPS: 30) == VideoSummary(duration: 5.5, frameCount: 165))
        #expect(source.converted(toFPS: nil) == source)
    }

    @Test func test_verify_accepts_an_export_within_tolerance() throws {
        let expected = VideoSummary(duration: 10, frameCount: 300)

        try VideoSummary(duration: 9.95, frameCount: 297).verify(matches: expected)
    }

    @Test func test_verify_rejects_dropped_frames() {
        let expected = VideoSummary(duration: 10, frameCount: 300)
        let exported = VideoSummary(duration: 10, frameCount: 250)

        #expect(throws: VideoSummary.Mismatch(expected: expected, actual: exported)) {
            try exported.verify(matches: expected)
        }
    }

    @Test func test_verify_rejects_a_short_export() {
        let expected = VideoSummary(duration: 10, frameCount: 300)
        let exported = VideoSummary(duration: 8, frameCount: 300)

        #expect(throws: VideoSummary.Mismatch(expected: expected, actual: exported)) {
            try exported.verify(matches: expected)
        }
    }
}
