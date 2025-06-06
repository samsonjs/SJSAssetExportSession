# Getting Started

Learn how to quickly set up and use SJSAssetExportSession for video exports.

## Overview

SJSAssetExportSession provides a simple yet powerful way to export videos with custom settings. This guide will walk you through the basic setup and your first export.

## Installation

Add SJSAssetExportSession to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/samhuri/SJSAssetExportSession.git", from: "0.3.0")
]
```

## Basic Usage

### Step 1: Import the Framework

```swift
import SJSAssetExportSession
import AVFoundation
```

### Step 2: Create an Export Session

```swift
let exporter = ExportSession()
```

### Step 3: Prepare Your Asset

```swift
let sourceURL = URL(fileURLWithPath: "path/to/your/video.mov")
let sourceAsset = AVURLAsset(url: sourceURL, options: [
    AVURLAssetPreferPreciseDurationAndTimingKey: true
])
```

> Important: Always use `AVURLAssetPreferPreciseDurationAndTimingKey: true` for accurate duration and timing information.

### Step 4: Define Your Output

```swift
let destinationURL = URL.temporaryDirectory.appending(component: "exported-video.mp4")
```

### Step 5: Export with Basic Settings

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

## Complete Example

Here's a complete example that includes progress monitoring:

```swift
import SJSAssetExportSession
import AVFoundation

func exportVideo() async throws {
    let sourceURL = URL(fileURLWithPath: "input.mov")
    let sourceAsset = AVURLAsset(url: sourceURL, options: [
        AVURLAssetPreferPreciseDurationAndTimingKey: true
    ])
    
    let destinationURL = URL.temporaryDirectory.appending(component: "output.mp4")
    
    let exporter = ExportSession()
    
    // Monitor progress
    Task {
        for await progress in exporter.progressStream {
            print("Export progress: \(Int(progress * 100))%")
        }
    }
    
    // Perform the export
    try await exporter.export(
        asset: sourceAsset,
        video: .codec(.h264, width: 1920, height: 1080)
            .fps(30)
            .bitrate(5_000_000),
        to: destinationURL,
        as: .mp4
    )
    
    print("Export completed successfully!")
}
```

## Next Steps

- Learn about <doc:AudioConfiguration> to customize audio settings
- Explore <doc:VideoConfiguration> for advanced video options
- Check out <doc:ExportingVideos> for more complex scenarios
- Read about <doc:ErrorHandling> to handle export failures gracefully

## Common Patterns

### Exporting a Video Clip

To export only a portion of a video:

```swift
try await exporter.export(
    asset: sourceAsset,
    timeRange: CMTimeRange(
        start: CMTime(seconds: 10, preferredTimescale: 600),
        duration: CMTime(seconds: 30, preferredTimescale: 600)
    ),
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

### Adding Metadata

Include metadata in your exported video:

```swift
let titleMetadata = AVMutableMetadataItem()
titleMetadata.key = AVMetadataKey.commonKeyTitle.rawValue as NSString
titleMetadata.keySpace = .common
titleMetadata.value = "My Video Title" as NSString

try await exporter.export(
    asset: sourceAsset,
    metadata: [titleMetadata],
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

### Optimizing for Network Playback

For videos that will be streamed or downloaded:

```swift
try await exporter.export(
    asset: sourceAsset,
    optimizeForNetworkUse: true,
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```