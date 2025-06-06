# Audio Configuration

Learn how to configure audio settings for your video exports.

## Overview

SJSAssetExportSession provides flexible audio configuration through the ``AudioOutputSettings`` builder pattern. You can easily specify format, channels, sample rate, and more advanced options.

## Basic Audio Settings

### Default AAC Configuration

The simplest approach uses the default AAC settings:

```swift
try await exporter.export(
    asset: sourceAsset,
    audio: .default,  // AAC, 2 channels, 44.1 kHz
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

The default configuration provides:
- Format: AAC (kAudioFormatMPEG4AAC)
- Channels: 2 (stereo)
- Sample Rate: 44,100 Hz

### Specifying Audio Format

Choose between supported audio formats:

```swift
// AAC format (recommended for MP4)
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac),
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)

// MP3 format
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.mp3),
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

## Channel Configuration

### Mono Audio

For voice recordings or to reduce file size:

```swift
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(1),
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

### Stereo Audio

Standard stereo configuration:

```swift
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(2),
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

### Multi-Channel Audio

For surround sound or complex audio setups:

```swift
// 5.1 surround sound
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(6),
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mov
)
```

## Sample Rate Configuration

### Common Sample Rates

Choose the appropriate sample rate for your content:

```swift
// CD quality (44.1 kHz)
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).sampleRate(44_100),
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)

// Professional audio (48 kHz)
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).sampleRate(48_000),
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mov
)

// High-resolution audio (96 kHz)
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).sampleRate(96_000),
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mov
)
```

### Reduced Quality for Web

For web streaming or mobile apps:

```swift
// Lower quality for smaller file size
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(1).sampleRate(22_050),
    video: .codec(.h264, width: 854, height: 480),
    to: destinationURL,
    as: .mp4
)
```

## Audio Format Guidelines

### AAC Format

Best for:
- MP4/MOV containers
- Streaming applications
- Mobile devices
- General compatibility

```swift
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(2).sampleRate(48_000),
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

### MP3 Format

Best for:
- Legacy compatibility
- Audio-focused applications
- When file size is critical

```swift
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.mp3).channels(2).sampleRate(44_100),
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

## Builder Pattern Chaining

Combine multiple audio settings using method chaining:

```swift
// Complete audio configuration
let audioSettings = AudioOutputSettings
    .format(.aac)
    .channels(2)
    .sampleRate(48_000)

try await exporter.export(
    asset: sourceAsset,
    audio: audioSettings,
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

## Audio Mix Integration

Combine audio settings with audio mix for advanced processing:

```swift
// Create an audio mix for volume control
let audioMix = AVMutableAudioMix()
let inputParameters = AVMutableAudioMixInputParameters(track: audioTrack)
inputParameters.setVolume(0.5, at: .zero)  // 50% volume
audioMix.inputParameters = [inputParameters]

try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(2).sampleRate(48_000),
    mix: audioMix,
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

## Audio-Only Exports

Export audio without video:

```swift
// Note: You still need to provide video settings, but the output will be audio-only
// if the source asset has no video tracks
try await exporter.export(
    asset: audioOnlyAsset,
    audio: .format(.aac).channels(2).sampleRate(44_100),
    video: .codec(.h264, width: 1, height: 1),  // Minimal video settings
    to: destinationURL,
    as: .m4a
)
```

## Common Audio Configurations

### Podcast Export

Optimized for speech content:

```swift
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(1).sampleRate(22_050),
    video: .codec(.h264, width: 640, height: 360),
    to: destinationURL,
    as: .mp4
)
```

### Music Video Export

High-quality audio for music content:

```swift
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(2).sampleRate(48_000),
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

### Social Media Export

Balanced quality for social platforms:

```swift
try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(2).sampleRate(44_100),
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

## Troubleshooting Audio Issues

### No Audio in Output

If your exported video has no audio:

1. Check that the source asset has audio tracks
2. Ensure audio settings are properly configured
3. Verify the output container supports your audio format

```swift
// Check for audio tracks
let audioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)
if audioTracks.isEmpty {
    print("Source asset has no audio tracks")
}
```

### Audio Quality Issues

For better audio quality:

- Use higher sample rates (48 kHz or higher)
- Choose AAC over MP3 when possible
- Ensure sufficient bitrate for your channel configuration

### Compatibility Issues

For maximum compatibility:

- Use AAC format with MP4 container
- Stick to standard sample rates (44.1 kHz, 48 kHz)
- Use stereo (2 channels) for general content

## See Also

- ``AudioOutputSettings`` - Audio settings builder
- ``AudioOutputSettings/Format`` - Supported audio formats
- <doc:VideoConfiguration> - Configuring video settings
- <doc:CustomSettings> - Using raw audio settings dictionaries