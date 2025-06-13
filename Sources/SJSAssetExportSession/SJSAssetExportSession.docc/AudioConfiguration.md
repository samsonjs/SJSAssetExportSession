# Audio Configuration

Configure audio export settings using the ``AudioOutputSettings`` builder pattern.

## Basic Configuration

```swift
// Default AAC settings (2 channels, 44.1 kHz)
.default

// Specify format
.format(.aac)  // Recommended for MP4/MOV
.format(.mp3)  // Legacy compatibility

// Full configuration
.format(.aac)
    .channels(2)
    .sampleRate(48_000)
```

## Common Configurations

```swift
// High quality stereo
.format(.aac).channels(2).sampleRate(48_000)

// Voice/podcast (mono, lower sample rate)
.format(.aac).channels(1).sampleRate(22_050)

// Music/professional
.format(.aac).channels(2).sampleRate(96_000)

// 5.1 surround
.format(.aac).channels(6).sampleRate(48_000)
```

## Sample Rates

- 22,050 Hz - Voice, low bandwidth
- 44,100 Hz - CD quality, general use
- 48,000 Hz - Professional video production
- 96,000 Hz - High-resolution audio

## Using with Exports

```swift
let exporter = ExportSession()

try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(2).sampleRate(48_000),
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

## Audio Mix Integration

```swift
// Create audio mix for volume control
let audioMix = AVMutableAudioMix()
let inputParameters = AVMutableAudioMixInputParameters(track: audioTrack)
inputParameters.setVolume(0.5, at: .zero)  // 50% volume
audioMix.inputParameters = [inputParameters]

try await exporter.export(
    asset: sourceAsset,
    audio: .format(.aac).channels(2),
    mix: audioMix,
    video: videoSettings,
    to: destinationURL,
    as: .mp4
)
```

## Troubleshooting

If no audio in output:
- Verify source has audio tracks: `asset.loadTracks(withMediaType: .audio)`
- Check container supports format (AAC for MP4/MOV)
- Ensure audio settings are specified

## See Also

- ``AudioOutputSettings`` - Audio settings builder
- ``AudioOutputSettings/Format`` - Supported formats