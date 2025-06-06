# Custom Settings

Learn how to use raw settings dictionaries for maximum control over export parameters.

## Overview

While SJSAssetExportSession provides convenient builder patterns through ``AudioOutputSettings`` and ``VideoOutputSettings``, you can also use raw settings dictionaries for complete control over export parameters. This approach gives you access to every AVFoundation setting while maintaining the benefits of the export session's architecture.

## Raw Settings API

### Using Raw Settings Dictionaries

The flexible export method accepts raw settings dictionaries:

```swift
try await exporter.export(
    asset: sourceAsset,
    audioOutputSettings: audioSettingsDict,
    videoOutputSettings: videoSettingsDict,
    to: destinationURL,
    as: .mp4
)
```

This method provides the most control over the export process and allows you to specify any settings supported by AVFoundation.

## Audio Settings Dictionaries

### Basic Audio Settings

```swift
let audioSettings: [String: any Sendable] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVNumberOfChannelsKey: NSNumber(value: 2),
    AVSampleRateKey: NSNumber(value: 48_000)
]

try await exporter.export(
    asset: sourceAsset,
    audioOutputSettings: audioSettings,
    videoOutputSettings: videoSettings,
    to: destinationURL,
    as: .mp4
)
```

### Advanced Audio Settings

```swift
let advancedAudioSettings: [String: any Sendable] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVNumberOfChannelsKey: NSNumber(value: 2),
    AVSampleRateKey: NSNumber(value: 48_000),
    AVEncoderBitRateKey: NSNumber(value: 128_000), // 128 kbps
    AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.high.rawValue),
    AVChannelLayoutKey: AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!.asData()
]
```

### Multi-Channel Audio

For surround sound configurations:

```swift
let surroundAudioSettings: [String: any Sendable] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVChannelLayoutKey: AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_5_1)!.asData(),
    AVSampleRateKey: NSNumber(value: 48_000),
    AVEncoderBitRateKey: NSNumber(value: 384_000) // Higher bitrate for 5.1
]
```

## Video Settings Dictionaries

### Basic Video Settings

```swift
let videoSettings: [String: any Sendable] = [
    AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
    AVVideoWidthKey: NSNumber(value: 1920),
    AVVideoHeightKey: NSNumber(value: 1080)
]

try await exporter.export(
    asset: sourceAsset,
    audioOutputSettings: audioSettings,
    videoOutputSettings: videoSettings,
    to: destinationURL,
    as: .mp4
)
```

### Advanced Video Settings

```swift
let advancedVideoSettings: [String: any Sendable] = [
    AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
    AVVideoWidthKey: NSNumber(value: 1920),
    AVVideoHeightKey: NSNumber(value: 1080),
    AVVideoCompressionPropertiesKey: [
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoAverageBitRateKey: NSNumber(value: 5_000_000),
        AVVideoMaxKeyFrameIntervalKey: NSNumber(value: 30),
        AVVideoAllowFrameReorderingKey: NSNumber(value: true),
        AVVideoExpectedSourceFrameRateKey: NSNumber(value: 30),
        AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
    ] as [String: any Sendable],
    AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
    ]
]
```

### HEVC Settings

```swift
let hevcSettings: [String: any Sendable] = [
    AVVideoCodecKey: AVVideoCodecType.hevc.rawValue,
    AVVideoWidthKey: NSNumber(value: 3840),
    AVVideoHeightKey: NSNumber(value: 2160),
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: NSNumber(value: 20_000_000),
        AVVideoQualityKey: NSNumber(value: 0.8),
        AVVideoMaxKeyFrameIntervalKey: NSNumber(value: 60)
    ] as [String: any Sendable],
    AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020
    ]
]
```

## Mix-and-Match Approach

### Bootstrap from Builder Patterns

Start with builder patterns and customize as needed:

```swift
// Start with builder pattern
var audioSettings = AudioOutputSettings
    .format(.aac)
    .channels(2)
    .sampleRate(48_000)
    .settingsDictionary

// Add custom settings
audioSettings[AVEncoderBitRateKey] = NSNumber(value: 192_000)
audioSettings[AVEncoderAudioQualityKey] = NSNumber(value: AVAudioQuality.max.rawValue)

var videoSettings = VideoOutputSettings
    .codec(.h264, width: 1920, height: 1080)
    .fps(30)
    .bitrate(5_000_000)
    .settingsDictionary

// Add advanced H.264 settings
if var compressionProps = videoSettings[AVVideoCompressionPropertiesKey] as? [String: any Sendable] {
    compressionProps[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC
    compressionProps[AVVideoAllowFrameReorderingKey] = NSNumber(value: true)
    videoSettings[AVVideoCompressionPropertiesKey] = compressionProps
}

try await exporter.export(
    asset: sourceAsset,
    audioOutputSettings: audioSettings,
    videoOutputSettings: videoSettings,
    to: destinationURL,
    as: .mp4
)
```

## Video Composition Integration

### Custom Video Composition

When using raw settings, you can provide your own video composition:

```swift
let videoComposition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: sourceAsset)
videoComposition.renderSize = CGSize(width: 1920, height: 1080)
videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30 fps

// Add filters or effects
let instruction = videoComposition.instructions.first as? AVMutableVideoCompositionInstruction
let layerInstruction = instruction?.layerInstructions.first as? AVMutableVideoCompositionLayerInstruction

// Apply transform or filters here...

try await exporter.export(
    asset: sourceAsset,
    audioOutputSettings: audioSettings,
    videoOutputSettings: videoSettings,
    composition: videoComposition,
    to: destinationURL,
    as: .mp4
)
```

## Advanced Use Cases

### Variable Bitrate Encoding

```swift
let vbrVideoSettings: [String: any Sendable] = [
    AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
    AVVideoWidthKey: NSNumber(value: 1920),
    AVVideoHeightKey: NSNumber(value: 1080),
    AVVideoCompressionPropertiesKey: [
        AVVideoQualityKey: NSNumber(value: 0.7), // Use quality instead of bitrate
        AVVideoMaxKeyFrameIntervalKey: NSNumber(value: 60),
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
    ] as [String: any Sendable]
]
```

### Custom Audio Channel Layout

```swift
// Create custom channel layout for 7.1 surround
let channelLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_7_1)!

let customAudioSettings: [String: any Sendable] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVChannelLayoutKey: channelLayout.asData(),
    AVSampleRateKey: NSNumber(value: 48_000),
    AVEncoderBitRateKey: NSNumber(value: 512_000) // Higher bitrate for 7.1
]
```

### Low-Latency Encoding

```swift
let lowLatencySettings: [String: any Sendable] = [
    AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
    AVVideoWidthKey: NSNumber(value: 1280),
    AVVideoHeightKey: NSNumber(value: 720),
    AVVideoCompressionPropertiesKey: [
        AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: NSNumber(value: 1), // I-frame only
        AVVideoAllowFrameReorderingKey: NSNumber(value: false),
        AVVideoRealTimeKey: NSNumber(value: true)
    ] as [String: any Sendable]
]
```

## Settings Validation

### Validating Custom Settings

```swift
func validateSettings(
    audioSettings: [String: any Sendable],
    videoSettings: [String: any Sendable],
    fileType: AVFileType
) throws {
    // Create temporary writer to validate settings
    let tempURL = URL.temporaryDirectory.appending(component: UUID().uuidString)
    let writer = try AVAssetWriter(outputURL: tempURL, fileType: fileType)
    
    // Validate audio settings if provided
    if !audioSettings.isEmpty {
        guard writer.canApply(outputSettings: audioSettings, forMediaType: .audio) else {
            throw ExportSession.Error.setupFailure(.audioSettingsInvalid)
        }
    }
    
    // Validate video settings
    guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else {
        throw ExportSession.Error.setupFailure(.videoSettingsInvalid)
    }
    
    // Clean up
    try? FileManager.default.removeItem(at: tempURL)
}
```

## Common Settings References

### H.264 Compression Properties

| Key | Type | Description |
|-----|------|-------------|
| `AVVideoAverageBitRateKey` | NSNumber | Average bitrate in bits per second |
| `AVVideoQualityKey` | NSNumber | Quality factor (0.0-1.0) |
| `AVVideoMaxKeyFrameIntervalKey` | NSNumber | Maximum keyframe interval |
| `AVVideoProfileLevelKey` | String | H.264 profile and level |
| `AVVideoAllowFrameReorderingKey` | NSNumber (Bool) | Enable B-frames |
| `AVVideoH264EntropyModeKey` | String | CAVLC or CABAC entropy mode |

### Audio Format Properties

| Key | Type | Description |
|-----|------|-------------|
| `AVFormatIDKey` | AudioFormatID | Audio codec identifier |
| `AVSampleRateKey` | NSNumber | Sample rate in Hz |
| `AVNumberOfChannelsKey` | NSNumber | Number of audio channels |
| `AVChannelLayoutKey` | Data | Channel layout information |
| `AVEncoderBitRateKey` | NSNumber | Audio bitrate in bits per second |
| `AVEncoderAudioQualityKey` | NSNumber | Audio quality setting |

## Performance Considerations

### Optimizing Custom Settings

```swift
// For fast encoding (lower quality)
let fastVideoSettings: [String: any Sendable] = [
    AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
    AVVideoWidthKey: NSNumber(value: 1280),
    AVVideoHeightKey: NSNumber(value: 720),
    AVVideoCompressionPropertiesKey: [
        AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
        AVVideoAverageBitRateKey: NSNumber(value: 2_000_000),
        AVVideoMaxKeyFrameIntervalKey: NSNumber(value: 12),
        AVVideoAllowFrameReorderingKey: NSNumber(value: false)
    ] as [String: any Sendable]
]

// For high quality (slower encoding)
let qualityVideoSettings: [String: any Sendable] = [
    AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
    AVVideoWidthKey: NSNumber(value: 1920),
    AVVideoHeightKey: NSNumber(value: 1080),
    AVVideoCompressionPropertiesKey: [
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoQualityKey: NSNumber(value: 0.9),
        AVVideoMaxKeyFrameIntervalKey: NSNumber(value: 30),
        AVVideoAllowFrameReorderingKey: NSNumber(value: true)
    ] as [String: any Sendable]
]
```

## Troubleshooting Custom Settings

### Common Issues

1. **Invalid Settings**: Always validate settings with `AVAssetWriter.canApply(outputSettings:forMediaType:)`
2. **Missing Required Keys**: Ensure `AVFormatIDKey` for audio and `AVVideoCodecKey` for video
3. **Type Mismatches**: Use `NSNumber` for numeric values, not Swift native types
4. **Channel Layout Data**: Convert `AVAudioChannelLayout` to `Data` using `asData()`

### Debug Settings

```swift
func debugSettings(_ settings: [String: any Sendable], mediaType: AVMediaType) {
    print("Settings for \(mediaType.rawValue):")
    for (key, value) in settings {
        print("  \(key): \(value)")
    }
    
    // Test with a temporary writer
    do {
        let tempURL = URL.temporaryDirectory.appending(component: "test")
        let writer = try AVAssetWriter(outputURL: tempURL, fileType: .mp4)
        let canApply = writer.canApply(outputSettings: settings, forMediaType: mediaType)
        print("  Can apply: \(canApply)")
        try? FileManager.default.removeItem(at: tempURL)
    } catch {
        print("  Validation error: \(error)")
    }
}
```

## See Also

- ``AudioOutputSettings`` - Audio settings builder
- ``VideoOutputSettings`` - Video settings builder
- <doc:AudioConfiguration> - Builder pattern for audio
- <doc:VideoConfiguration> - Builder pattern for video
- <doc:ErrorHandling> - Handling settings validation errors