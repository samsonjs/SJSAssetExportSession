// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SJSAssetExportSession",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "SJSAssetExportSession",
            targets: ["SJSAssetExportSession"]),
    ],
    targets: [
        .target(name: "SJSAssetExportSession"),
        .testTarget(
            name: "SJSAssetExportSessionTests",
            dependencies: ["SJSAssetExportSession"],
            resources: [
                .process("Resources/test-4k-hdr-hevc-30fps.mov"),
                .process("Resources/test-720p-h264-24fps.mov"),
                .process("Resources/test-no-audio.mp4"),
                .process("Resources/test-no-video.m4a"),
            ]
        ),
    ]
)
