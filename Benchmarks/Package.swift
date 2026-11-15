// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SJSAssetExportSessionBenchmarks",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(name: "SJSAssetExportSession", path: ".."),
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.38.1", traits: []),
    ],
    targets: [
        .target(
            name: "BenchmarkSupport"
        ),
        .testTarget(
            name: "BenchmarkSupportTests",
            dependencies: ["BenchmarkSupport"]
        ),
        .executableTarget(
            name: "ExportBenchmarks",
            dependencies: [
                "BenchmarkSupport",
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "SJSAssetExportSession", package: "SJSAssetExportSession"),
            ],
            path: "Benchmarks/ExportBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark"),
            ]
        ),
    ]
)
