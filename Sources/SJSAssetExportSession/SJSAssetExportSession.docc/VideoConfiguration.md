# Video Configuration

Configure video export settings using the ``VideoOutputSettings`` builder pattern.

## Basic Configuration

```swift
// H.264 - Maximum compatibility
.codec(.h264, width: 1920, height: 1080)

// HEVC - Better compression
.codec(.hevc, width: 3840, height: 2160)

// With additional settings
.codec(.h264, width: 1920, height: 1080)
    .fps(30)
    .bitrate(5_000_000)
    .color(.sdr)
```

## H.264 Profiles

```swift
// Auto-select appropriate level
.codec(.h264(.baselineAuto), width: 1280, height: 720)  // Maximum compatibility
.codec(.h264(.mainAuto), width: 1920, height: 1080)     // Balanced (default)
.codec(.h264(.highAuto), width: 1920, height: 1080)     // Best compression

// Specific levels for precise control
.codec(.h264(.baseline31), width: 1280, height: 720)    // Web compatibility
.codec(.h264(.high41), width: 1920, height: 1080)       // Modern devices
```

## Frame Rates

```swift
.fps(24)  // Cinematic
.fps(30)  // Standard video
.fps(60)  // High motion content
```

## Bitrates

Rough guidelines for quality vs file size:

| Resolution | 30fps | 60fps |
|------------|-------|-------|
| 720p       | 2-4 Mbps | 4-6 Mbps |
| 1080p      | 4-8 Mbps | 8-12 Mbps |
| 4K         | 15-25 Mbps | 25-40 Mbps |

## Color Spaces

```swift
.color(.sdr)  // Standard Dynamic Range (BT.709)
.color(.hdr)  // High Dynamic Range (BT.2020 with HLG)
```

## Complete Examples

```swift
// Social media optimized
.codec(.h264(.mainAuto), width: 1280, height: 720)
    .fps(30)
    .bitrate(2_000_000)
    .color(.sdr)

// Professional quality
.codec(.hevc, width: 3840, height: 2160)
    .fps(24)
    .bitrate(20_000_000)
    .color(.hdr)

// Web streaming (with network optimization)
try await exporter.export(
    asset: sourceAsset,
    optimizeForNetworkUse: true,
    video: .codec(.h264(.baseline31), width: 854, height: 480)
        .fps(24)
        .bitrate(800_000),
    to: destinationURL,
    as: .mp4
)
```

## Performance Notes

- Baseline profile encodes fastest but produces larger files
- High profile encodes slower but achieves better compression
- HEVC provides best compression but requires more processing power
- Higher resolutions and frame rates significantly impact encoding time

## See Also

- ``VideoOutputSettings`` - Video settings builder
- ``VideoOutputSettings/Codec`` - Supported codecs
- ``VideoOutputSettings/H264Profile`` - H.264 profiles