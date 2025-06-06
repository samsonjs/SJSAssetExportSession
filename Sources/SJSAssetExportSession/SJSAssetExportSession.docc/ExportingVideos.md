# Exporting Videos

Comprehensive guide to video export scenarios and best practices.

## Overview

This guide covers various video export scenarios, from simple conversions to complex multi-track compositions with custom settings.

## Basic Video Export

### Simple Format Conversion

Convert between video formats while maintaining quality:

```swift
let exporter = ExportSession()

try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

### Changing Resolution

Scale video to different resolutions:

```swift
// 4K to 1080p
try await exporter.export(
    asset: source4KAsset,
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)

// 1080p to 720p
try await exporter.export(
    asset: source1080pAsset,
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

## Advanced Video Configuration

### High-Quality Exports

For maximum quality, use HEVC with high bitrates:

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.hevc, width: 3840, height: 2160)
        .fps(60)
        .bitrate(20_000_000)  // 20 Mbps
        .color(.hdr),
    to: destinationURL,
    as: .mov
)
```

### Optimized for Social Media

Twitter-optimized export:

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1280, height: 720)
        .fps(30)
        .bitrate(2_000_000),  // 2 Mbps
    to: destinationURL,
    as: .mp4
)
```

Instagram-optimized export:

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1080, height: 1080)  // Square aspect ratio
        .fps(30)
        .bitrate(3_500_000),  // 3.5 Mbps
    to: destinationURL,
    as: .mp4
)
```

### Web Streaming

Optimize for web playback with multiple bitrates:

```swift
// Low bitrate for mobile
try await exporter.export(
    asset: sourceAsset,
    optimizeForNetworkUse: true,
    video: .codec(.h264, width: 854, height: 480)
        .fps(24)
        .bitrate(800_000),  // 800 Kbps
    to: lowQualityURL,
    as: .mp4
)

// High bitrate for desktop
try await exporter.export(
    asset: sourceAsset,
    optimizeForNetworkUse: true,
    video: .codec(.h264, width: 1920, height: 1080)
        .fps(30)
        .bitrate(5_000_000),  // 5 Mbps
    to: highQualityURL,
    as: .mp4
)
```

## Working with Time Ranges

### Creating Clips

Extract specific segments from longer videos:

```swift
// First 30 seconds
let clipRange = CMTimeRange(
    start: .zero,
    duration: CMTime(seconds: 30, preferredTimescale: 600)
)

try await exporter.export(
    asset: sourceAsset,
    timeRange: clipRange,
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

### Removing Sections

Skip a middle section by exporting multiple clips:

```swift
// Export first part (0-60 seconds)
let part1Range = CMTimeRange(
    start: .zero,
    duration: CMTime(seconds: 60, preferredTimescale: 600)
)

// Export second part (120 seconds to end)
let part2Start = CMTime(seconds: 120, preferredTimescale: 600)
let totalDuration = try await sourceAsset.load(.duration)
let part2Range = CMTimeRange(
    start: part2Start,
    duration: totalDuration - part2Start
)

// Export each part separately
try await exporter.export(
    asset: sourceAsset,
    timeRange: part1Range,
    video: .codec(.h264, width: 1280, height: 720),
    to: part1URL,
    as: .mp4
)

try await exporter.export(
    asset: sourceAsset,
    timeRange: part2Range,
    video: .codec(.h264, width: 1280, height: 720),
    to: part2URL,
    as: .mp4
)
```

## Color Management

### Standard Dynamic Range (SDR)

For compatibility with most devices:

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080)
        .color(.sdr),
    to: destinationURL,
    as: .mp4
)
```

### High Dynamic Range (HDR)

Preserve HDR content for compatible displays:

```swift
try await exporter.export(
    asset: hdrSourceAsset,
    video: .codec(.hevc, width: 3840, height: 2160)
        .color(.hdr),
    to: destinationURL,
    as: .mov
)
```

## File Format Considerations

### MP4 vs MOV

**MP4** - Best for:
- Web streaming
- Mobile devices
- General compatibility

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

**MOV** - Best for:
- Professional workflows
- HDR content
- Apple ecosystem

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.hevc, width: 3840, height: 2160),
    to: destinationURL,
    as: .mov
)
```

## Performance Optimization

### Choosing Appropriate Settings

Balance quality and performance based on your use case:

```swift
// Fast export (lower quality)
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.baseline30), width: 1280, height: 720)
        .fps(24)
        .bitrate(1_500_000),
    to: destinationURL,
    as: .mp4
)

// Balanced export
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.main32), width: 1920, height: 1080)
        .fps(30)
        .bitrate(4_000_000),
    to: destinationURL,
    as: .mp4
)

// High quality export (slower)
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.high41), width: 1920, height: 1080)
        .fps(60)
        .bitrate(8_000_000),
    to: destinationURL,
    as: .mp4
)
```

### Progress Monitoring

Provide user feedback during long exports:

```swift
let exporter = ExportSession()

Task {
    for await progress in exporter.progressStream {
        await MainActor.run {
            progressView.progress = progress
            progressLabel.text = "\(Int(progress * 100))%"
        }
    }
}

try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

## Error Handling

Always wrap exports in proper error handling:

```swift
do {
    try await exporter.export(
        asset: sourceAsset,
        video: .codec(.h264, width: 1920, height: 1080),
        to: destinationURL,
        as: .mp4
    )
    print("Export completed successfully")
} catch let error as ExportSession.Error {
    switch error {
    case .setupFailure(let reason):
        print("Setup failed: \(reason)")
    case .readFailure(let underlyingError):
        print("Read failed: \(underlyingError?.localizedDescription ?? "Unknown")")
    case .writeFailure(let underlyingError):
        print("Write failed: \(underlyingError?.localizedDescription ?? "Unknown")")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## See Also

- <doc:AudioConfiguration> - Adding audio to your exports
- <doc:CustomSettings> - Using raw settings dictionaries
- <doc:PerformanceOptimization> - Optimizing export performance