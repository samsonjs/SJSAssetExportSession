import Foundation

/// Finds the media benchmarks export: the fixtures checked in with the package's tests, and the
/// larger bundle of real clips downloaded by `Benchmarks/fetch-media`.
public struct BenchmarkMedia: Sendable {
    /// The bundle version that `Benchmarks/fetch-media` downloads. Bump both when the clips change.
    public static let bundleVersion = "v1"

    public static let directoryEnvironmentKey = "SJS_BENCHMARK_MEDIA_DIR"

    public let fixturesDirectory: URL
    public let bundleDirectory: URL

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        cachesDirectory: URL = .cachesDirectory
    ) {
        fixturesDirectory = URL(filePath: #filePath)
            .deletingLastPathComponent() // BenchmarkSupport
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // Benchmarks
            .deletingLastPathComponent() // package root
            .appending(components: "Tests", "SJSAssetExportSessionTests", "Resources")
        bundleDirectory = if let path = environment[Self.directoryEnvironmentKey] {
            URL(filePath: path)
        } else {
            cachesDirectory.appending(
                components: "SJSAssetExportSession", "benchmark-media-\(Self.bundleVersion)"
            )
        }
    }

    public func fixture(_ name: String) -> URL {
        fixturesDirectory.appending(component: name)
    }

    /// The bundled clip with this name, or nil when the bundle hasn't been downloaded.
    public func bundled(_ name: String) -> URL? {
        let url = bundleDirectory.appending(component: name)
        return FileManager.default.fileExists(atPath: url.path()) ? url : nil
    }
}
