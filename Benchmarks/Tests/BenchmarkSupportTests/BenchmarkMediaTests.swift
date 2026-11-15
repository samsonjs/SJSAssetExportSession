import BenchmarkSupport
import Foundation
import Testing

struct BenchmarkMediaTests {
    @Test func test_fixtures_directory_holds_the_test_fixtures() {
        let media = BenchmarkMedia(environment: [:])

        let fixture = media.fixture("test-720p-h264-24fps.mov")

        #expect(FileManager.default.fileExists(atPath: fixture.path()))
    }

    @Test func test_bundle_directory_defaults_to_the_caches_directory() {
        let caches = URL(filePath: "/Users/greg-graffin/Library/Caches")

        let media = BenchmarkMedia(environment: [:], cachesDirectory: caches)

        #expect(media.bundleDirectory == caches.appending(
            components: "SJSAssetExportSession", "benchmark-media-\(BenchmarkMedia.bundleVersion)"
        ))
    }

    @Test func test_bundle_directory_can_be_set_in_the_environment() {
        let media = BenchmarkMedia(environment: ["SJS_BENCHMARK_MEDIA_DIR": "/Volumes/Punk/clips"])

        #expect(media.bundleDirectory == URL(filePath: "/Volumes/Punk/clips"))
    }

    @Test func test_bundled_clip_is_nil_until_it_is_downloaded() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let media = BenchmarkMedia(environment: ["SJS_BENCHMARK_MEDIA_DIR": directory.path()])

        #expect(media.bundled("bad-religion-live.mov") == nil)
    }

    @Test func test_bundled_clip_is_found_once_it_is_downloaded() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let media = BenchmarkMedia(environment: ["SJS_BENCHMARK_MEDIA_DIR": directory.path()])
        let clip = directory.appending(component: "bad-religion-live.mov")
        try FileManager.default.copyItem(at: media.fixture("test-720p-h264-24fps.mov"), to: clip)

        #expect(media.bundled("bad-religion-live.mov") == clip)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL.temporaryDirectory.appending(component: "benchmark-media-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
