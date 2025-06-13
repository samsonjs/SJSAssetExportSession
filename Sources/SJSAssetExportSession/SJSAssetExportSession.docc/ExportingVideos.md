# Exporting Videos

Export videos with custom settings and format conversion.

## Basic Export

```swift
let exporter = ExportSession()

// Simple format conversion
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)

// Change resolution and codec
try await exporter.export(
    asset: source4KAsset,
    video: .codec(.hevc, width: 1920, height: 1080)
        .fps(30)
        .bitrate(4_000_000),
    to: destinationURL,
    as: .mov
)
```

## Time Ranges

Extract clips or segments:

```swift
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

## Color Spaces

```swift
// SDR for compatibility
.color(.sdr)

// HDR for supported displays
.color(.hdr)
```

## H.264 Profiles

```swift
// Fast encoding, lower compression
.codec(.h264(.baseline30), width: 1280, height: 720)

// Balanced (default)
.codec(.h264(.main32), width: 1920, height: 1080)

// Best compression, slower
.codec(.h264(.high41), width: 1920, height: 1080)
```

## Progress Tracking

```swift
Task {
    for await progress in exporter.progressStream {
        // Update UI with progress (0.0 to 1.0)
    }
}

try await exporter.export(...)
```

## Error Handling

```swift
do {
    try await exporter.export(...)
} catch let error as ExportSession.Error {
    switch error {
    case .setupFailure(let reason):
        // Handle setup errors
    case .readFailure(let underlyingError):
        // Handle read errors
    case .writeFailure(let underlyingError):
        // Handle write errors
    }
}
```

## See Also

- <doc:VideoConfiguration> - Video settings in detail