# Video Configuration

Comprehensive guide to configuring video settings for optimal export results.

## Overview

SJSAssetExportSession provides extensive video configuration options through the ``VideoOutputSettings`` builder pattern. Configure codecs, resolution, frame rates, bitrates, and color properties to achieve the perfect balance of quality and file size for your use case.

## Basic Video Settings

### Choosing a Codec

Select the appropriate codec for your target platform and quality requirements:

```swift
// H.264 - Maximum compatibility
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)

// HEVC - Better compression, newer devices
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.hevc, width: 3840, height: 2160),
    to: destinationURL,
    as: .mov
)
```

### Setting Resolution

Specify exact dimensions for your output video:

```swift
// Common resolutions
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080),  // 1080p
    to: destinationURL,
    as: .mp4
)

try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1280, height: 720),   // 720p
    to: destinationURL,
    as: .mp4
)

try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 3840, height: 2160),  // 4K
    to: destinationURL,
    as: .mov
)
```

You can also use `CGSize` for resolution:

```swift
let resolution = CGSize(width: 1920, height: 1080)
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, size: resolution),
    to: destinationURL,
    as: .mp4
)
```

## Frame Rate Configuration

### Standard Frame Rates

Set the output frame rate to match your content or target platform:

```swift
// 24 fps - Cinematic content
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080)
        .fps(24),
    to: destinationURL,
    as: .mp4
)

// 30 fps - Standard video content
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080)
        .fps(30),
    to: destinationURL,
    as: .mp4
)

// 60 fps - High motion content
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080)
        .fps(60),
    to: destinationURL,
    as: .mp4
)
```

### Frame Rate Considerations

- **24 fps**: Film and cinematic content
- **25/30 fps**: Standard broadcast and web video
- **50/60 fps**: Sports, gaming, high-motion content
- **120+ fps**: Slow-motion source material

## Bitrate Configuration

### Quality vs. File Size

Balance video quality with file size using bitrate settings:

```swift
// Low bitrate - Smaller file, lower quality
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1280, height: 720)
        .fps(30)
        .bitrate(1_000_000),  // 1 Mbps
    to: destinationURL,
    as: .mp4
)

// Medium bitrate - Balanced
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080)
        .fps(30)
        .bitrate(5_000_000),  // 5 Mbps
    to: destinationURL,
    as: .mp4
)

// High bitrate - Maximum quality
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080)
        .fps(30)
        .bitrate(15_000_000), // 15 Mbps
    to: destinationURL,
    as: .mp4
)
```

### Recommended Bitrates

| Resolution | Frame Rate | Recommended Bitrate |
|------------|------------|-------------------|
| 720p       | 30 fps     | 2-4 Mbps         |
| 1080p      | 30 fps     | 4-8 Mbps         |
| 1080p      | 60 fps     | 8-12 Mbps        |
| 4K         | 30 fps     | 15-25 Mbps       |
| 4K         | 60 fps     | 25-40 Mbps       |

## H.264 Profile Configuration

### Profile Selection

Choose the appropriate H.264 profile for your target devices:

```swift
// Baseline - Maximum compatibility (older devices)
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.baselineAuto), width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)

// Main - Good compatibility with better compression
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.mainAuto), width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)

// High - Best compression, modern devices
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.highAuto), width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

### Specific Profile Levels

For precise control over encoding parameters:

```swift
// Baseline Level 3.1 - Web compatibility
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.baseline31), width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)

// High Level 4.1 - Modern devices
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.high41), width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

## Color Configuration

### Standard Dynamic Range (SDR)

For maximum compatibility across devices:

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080)
        .color(.sdr),
    to: destinationURL,
    as: .mp4
)
```

SDR uses the BT.709 color space, which corresponds roughly to sRGB and is supported by virtually all displays.

### High Dynamic Range (HDR)

For premium content with enhanced color and brightness:

```swift
try await exporter.export(
    asset: hdrSourceAsset,
    video: .codec(.hevc, width: 3840, height: 2160)
        .color(.hdr),
    to: destinationURL,
    as: .mov
)
```

HDR uses the BT.2020 color space with HLG transfer function, providing wider color gamut and higher dynamic range.

## Complete Configuration Examples

### Social Media Optimized

Twitter/X optimized export:

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.mainAuto), width: 1280, height: 720)
        .fps(30)
        .bitrate(2_000_000)
        .color(.sdr),
    to: destinationURL,
    as: .mp4
)
```

Instagram optimized export:

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.mainAuto), width: 1080, height: 1080)  // Square
        .fps(30)
        .bitrate(3_500_000)
        .color(.sdr),
    to: destinationURL,
    as: .mp4
)
```

### Professional Video

High-quality export for professional use:

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.hevc, width: 3840, height: 2160)
        .fps(24)
        .bitrate(20_000_000)
        .color(.hdr),
    to: destinationURL,
    as: .mov
)
```

### Web Streaming

Optimized for web playback:

```swift
// Low quality variant
try await exporter.export(
    asset: sourceAsset,
    optimizeForNetworkUse: true,
    video: .codec(.h264(.baseline31), width: 854, height: 480)
        .fps(24)
        .bitrate(800_000)
        .color(.sdr),
    to: lowQualityURL,
    as: .mp4
)

// High quality variant
try await exporter.export(
    asset: sourceAsset,
    optimizeForNetworkUse: true,
    video: .codec(.h264(.high40), width: 1920, height: 1080)
        .fps(30)
        .bitrate(5_000_000)
        .color(.sdr),
    to: highQualityURL,
    as: .mp4
)
```

## Builder Pattern Chaining

Combine all video settings using method chaining:

```swift
let videoSettings = VideoOutputSettings
    .codec(.h264(.highAuto), width: 1920, height: 1080)
    .fps(30)
    .bitrate(5_000_000)
    .color(.sdr)

try await exporter.export(
    asset: sourceAsset,
    video: videoSettings,
    to: destinationURL,
    as: .mp4
)
```

## Video Composition Integration

Video settings work seamlessly with AVVideoComposition:

```swift
let videoComposition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: sourceAsset)

// The video settings will be applied to the composition automatically
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080)
        .fps(24)
        .color(.sdr),
    to: destinationURL,
    as: .mp4
)
```

## Performance Considerations

### Encoding Speed vs. Quality

- **Baseline Profile**: Fastest encoding, largest file size
- **Main Profile**: Balanced encoding speed and compression
- **High Profile**: Slower encoding, best compression
- **HEVC**: Slowest encoding, best compression for modern devices

### Resolution and Performance

Higher resolutions require more processing power:

```swift
// Fast export - lower resolution
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.baseline31), width: 1280, height: 720)
        .fps(24)
        .bitrate(2_000_000),
    to: destinationURL,
    as: .mp4
)

// Slow export - higher resolution
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.hevc, width: 3840, height: 2160)
        .fps(60)
        .bitrate(25_000_000),
    to: destinationURL,
    as: .mov
)
```

## Common Video Configurations

### YouTube Upload

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.highAuto), width: 1920, height: 1080)
        .fps(30)
        .bitrate(8_000_000)
        .color(.sdr),
    to: destinationURL,
    as: .mp4
)
```

### Mobile App

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.mainAuto), width: 1280, height: 720)
        .fps(30)
        .bitrate(2_500_000)
        .color(.sdr),
    to: destinationURL,
    as: .mp4
)
```

### Archive/Storage

```swift
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.hevc, width: 1920, height: 1080)
        .fps(24)
        .bitrate(3_000_000)
        .color(.sdr),
    to: destinationURL,
    as: .mov
)
```

## See Also

- ``VideoOutputSettings`` - Video settings builder
- ``VideoOutputSettings/Codec`` - Supported video codecs
- ``VideoOutputSettings/H264Profile`` - H.264 profile options
- ``VideoOutputSettings/Color`` - Color space configuration
- <doc:AudioConfiguration> - Configuring audio settings
- <doc:CustomSettings> - Using raw video settings dictionaries