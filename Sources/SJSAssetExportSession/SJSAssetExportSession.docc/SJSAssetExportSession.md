# ``SJSAssetExportSession``

A Swift-first alternative to AVAssetExportSession with custom audio/video settings and strict concurrency support.

## Overview

`SJSAssetExportSession` is a modern Swift package that provides an alternative to `AVAssetExportSession` with full control over audio and video export settings. Unlike the built-in `AVAssetExportSession`, this library allows you to specify custom codec settings, bitrates, frame rates, and color properties without having to work directly with `AVAssetReader` and `AVAssetWriter`.

### Key Features

- **Two-tier API Design**: Choose between a simple builder pattern or raw settings dictionaries for maximum flexibility
- **Swift 6 Strict Concurrency**: Built from the ground up with `Sendable` types and async/await
- **Real-time Progress Reporting**: Monitor export progress via `AsyncStream<Float>`
- **Comprehensive Format Support**: H.264, HEVC, AAC, MP3, and more
- **Advanced Color Management**: Support for both SDR (BT.709) and HDR (BT.2020) workflows
- **Mix-and-Match Approach**: Bootstrap custom settings from builder patterns for ultimate flexibility

### Why SJSAssetExportSession?

[`AVAssetExportSession`][AV] provides limited customization options, essentially restricting you to the presets it offers. This package gives you the control you need while maintaining a simple, Swift-friendly API.

[AV]: https://developer.apple.com/documentation/avfoundation/avassetexportsession

Instead of wrestling with complex [audio settings][] and [video settings][] dictionaries, you can use the builder pattern to construct exactly what you need:

[audio settings]: https://developer.apple.com/documentation/avfoundation/audio_settings
[video settings]: https://developer.apple.com/documentation/avfoundation/video_settings

```swift
let exporter = ExportSession()
Task {
    for await progress in exporter.progressStream {
        print("Export progress: \(progress)")
    }
}

try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(2).sampleRate(48_000),
    video: .codec(.h264, width: 1920, height: 1080)
        .fps(30)
        .bitrate(5_000_000)
        .color(.sdr),
    to: destinationURL,
    as: .mp4
)
```

## Getting Started

### Basic Export

The simplest way to get started is with a basic video export:

```swift
let exporter = ExportSession()
try await exporter.export(
    asset: AVURLAsset(url: sourceURL),
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

### Monitoring Progress

Track export progress using the built-in progress stream:

```swift
let exporter = ExportSession()
Task {
    for await progress in exporter.progressStream {
        DispatchQueue.main.async {
            progressView.progress = progress
        }
    }
}
try await exporter.export(/* ... */)
```

### Advanced Configuration

For more control, specify custom audio settings, metadata, and time ranges:

```swift
try await exporter.export(
    asset: sourceAsset,
    optimizeForNetworkUse: true,
    metadata: [locationMetadata],
    timeRange: CMTimeRange(start: .zero, duration: .seconds(30)),
    audio: .format(.mp3).channels(1).sampleRate(22_050),
    video: .codec(.hevc, width: 3840, height: 2160)
        .fps(60)
        .bitrate(15_000_000)
        .color(.hdr),
    to: destinationURL,
    as: .mov
)
```

## Topics

### Essentials

- ``ExportSession``
- <doc:GettingStarted>
- <doc:ExportingVideos>

### Audio Configuration

- ``AudioOutputSettings``
- ``AudioOutputSettings/Format``
- <doc:AudioConfiguration>

### Video Configuration

- ``VideoOutputSettings``
- ``VideoOutputSettings/Codec``
- ``VideoOutputSettings/H264Profile``
- ``VideoOutputSettings/Color``
- <doc:VideoConfiguration>

### Error Handling

- ``ExportSession/Error``
- ``ExportSession/SetupFailureReason``
- <doc:ErrorHandling>

### Advanced Topics

- <doc:CustomSettings>
- <doc:ProgressTracking>
- <doc:PerformanceOptimization>
