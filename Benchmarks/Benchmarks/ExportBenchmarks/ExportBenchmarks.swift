import AVFoundation
import Benchmark
import BenchmarkSupport
import Foundation
import SJSAssetExportSession

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(
        metrics: [.instructions, .peakMemoryResident, .wallClock, .cpuTotal],
        warmupIterations: 1,
        maxDuration: .seconds(60),
        maxIterations: 5,
        thresholds: [
            .instructions: .init(relative: [.p50: 20]),
            .peakMemoryResident: .init(relative: [.p50: 25]),
            // Reported but never failed on: on a busy machine both moved by more than 50% between
            // two runs of the same code.
            .wallClock: .init(),
            .cpuTotal: .init(),
        ]
    )

    let media = BenchmarkMedia()

    // Fixtures checked in with the tests, so these run on a fresh clone.

    let fixture4KHDR = media.fixture("test-4k-hdr-hevc-30fps.mov")
    exportBenchmark(
        "Fixture 4K HDR HEVC to 1080p H.264",
        source: fixture4KHDR,
        video: .codec(.h264, width: 1920, height: 1080)
    )
    exportBenchmark(
        "Fixture 4K HDR HEVC to 1080p HDR HEVC",
        source: fixture4KHDR,
        video: .codec(.hevc, width: 1920, height: 1080).color(.hdr)
    )
    exportBenchmark(
        "Fixture 4K HDR HEVC to 1080p H.264 drawing frames",
        source: fixture4KHDR,
        video: .codec(.h264, width: 1920, height: 1080),
        drawsFrames: true
    )
    exportBenchmark(
        "Fixture 1080p60 H.264 to 30 fps",
        source: media.fixture("test-x264-1080p-h264-60fps.mp4"),
        video: .codec(.h264, width: 1920, height: 1080).fps(30)
    )
    exportBenchmark(
        "Fixture spatial audio to stereo",
        source: media.fixture("test-spatial-audio.mov"),
        video: .codec(.h264, width: 1920, height: 1080)
    )
    exportBenchmark(
        "Fixture 5.1 audio to stereo",
        source: media.fixture("test-5.1-audio.mp4"),
        video: .codec(.h264, width: 64, height: 64)
    )
    referenceBenchmark(
        "AVAssetExportSession fixture 4K HDR HEVC to 1080p",
        source: fixture4KHDR,
        preset: AVAssetExportPreset1920x1080
    )

    // Real clips downloaded by Benchmarks/fetch-media.

    guard let portrait = media.bundled("hdr-hlg-4k60-portrait-spatial-audio.mov"),
          let landscape = media.bundled("hdr-hlg-4k60-landscape-spatial-audio.mov"),
          let sdrHEVC = media.bundled("sdr-hevc-1080p30-41s.mov"),
          let sdrH264 = media.bundled("sdr-h264-1080p60-mono-audio.mov"),
          let longSDRH264 = media.bundled("sdr-h264-1080p60-mono-audio-113s.mov"),
          let livePhoto = media.bundled("live-photo-hevc-lpcm-audio.mov")
    else {
        FileHandle.standardError.write(Data("""
            Skipping the bundle benchmarks because the media isn't in \(media.bundleDirectory.path()).
            Run Benchmarks/fetch-media, or set \(BenchmarkMedia.directoryEnvironmentKey).

            """.utf8))
        return
    }

    exportBenchmark(
        "Bundle 4K60 HLG portrait to 1080p H.264",
        source: portrait,
        video: .codec(.h264, width: 1080, height: 1920)
    )
    exportBenchmark(
        "Bundle 4K60 HLG landscape to 1080p30 HDR HEVC",
        source: landscape,
        video: .codec(.hevc, width: 1920, height: 1080).fps(30).color(.hdr)
    )
    exportBenchmark(
        "Bundle 4K60 HLG landscape to 1080p H.264 drawing frames",
        source: landscape,
        video: .codec(.h264, width: 1920, height: 1080),
        drawsFrames: true
    )
    exportBenchmark(
        "Bundle 1080p30 SDR HEVC 41s to 720p H.264",
        source: sdrHEVC,
        video: .codec(.h264, width: 1280, height: 720)
    )
    exportBenchmark(
        "Bundle 1080p60 H.264 to 30 fps",
        source: sdrH264,
        video: .codec(.h264, width: 1920, height: 1080).fps(30)
    )
    exportBenchmark(
        "Bundle 1080p60 H.264 113s to 720p30 H.264",
        source: longSDRH264,
        video: .codec(.h264, width: 1280, height: 720).fps(30)
    )
    exportBenchmark(
        "Bundle Live Photo with LPCM audio to H.264",
        source: livePhoto,
        video: .codec(.h264, width: 1080, height: 1440)
    )
    referenceBenchmark(
        "AVAssetExportSession bundle 4K60 HLG portrait to 1080p",
        source: portrait,
        preset: AVAssetExportPreset1920x1080
    )
}

/// Times one export of `source`, then checks the output has every frame it should have, so an
/// export can't get faster by doing less.
func exportBenchmark(
    _ name: String,
    source: URL,
    video: VideoOutputSettings,
    drawsFrames: Bool = false
) {
    Benchmark(name) { (benchmark: Benchmark) async throws in
        let expected = try await VideoSummary.of(source).converted(toFPS: video.fps)
        var artist: FrameArtist?
        if drawsFrames {
            artist = { frame in stampWatermark(frame) }
        }
        let outputURL = makeOutputURL()
        defer { try? FileManager.default.removeItem(at: outputURL) }

        benchmark.startMeasurement()
        try await ExportSession().export(
            asset: makeAsset(source),
            video: video,
            drawFrame: artist,
            to: outputURL,
            as: .mp4
        )
        benchmark.stopMeasurement()

        try await VideoSummary.of(outputURL).verify(matches: expected)
    }
}

/// Times `AVAssetExportSession` exporting `source`, as a yardstick for the library's numbers on
/// the same machine.
func referenceBenchmark(_ name: String, source: URL, preset: String) {
    Benchmark(name) { (benchmark: Benchmark) async throws in
        let expected = try await VideoSummary.of(source)
        let outputURL = makeOutputURL()
        defer { try? FileManager.default.removeItem(at: outputURL) }
        guard let session = AVAssetExportSession(asset: makeAsset(source), presetName: preset) else {
            throw ReferenceError.unsupportedPreset(preset)
        }

        benchmark.startMeasurement()
        try await session.export(to: outputURL, as: .mp4)
        benchmark.stopMeasurement()

        try await VideoSummary.of(outputURL).verify(matches: expected)
    }
}

enum ReferenceError: Error {
    case unsupportedPreset(String)
}

func makeAsset(_ url: URL) -> AVURLAsset {
    AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
}

func makeOutputURL() -> URL {
    URL.temporaryDirectory.appending(component: "export-benchmark-\(UUID().uuidString).mp4")
}

/// Stamps a small square into the top left corner of the luma plane, the way a watermark would.
func stampWatermark(_ frame: VideoFrame) {
    let pixelBuffer = frame.pixelBuffer
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return }
    let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
    let is10Bit = CVPixelBufferGetPixelFormatType(pixelBuffer)
        == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
    let side = 64
    for row in 0 ..< side {
        memset(base + row * bytesPerRow, 0xEB, side * (is10Bit ? 2 : 1))
    }
}
