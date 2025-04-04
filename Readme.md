# SJSAssetExportSession

[![0 dependencies!](https://0dependencies.dev/0dependencies.svg)](https://0dependencies.dev)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsamsonjs%2FSJSAssetExportSession%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/samsonjs/SJSAssetExportSession)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsamsonjs%2FSJSAssetExportSession%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/samsonjs/SJSAssetExportSession)

## Overview

`SJSAssetExportSession` is an alternative to [`AVAssetExportSession`][AV] that lets you provide custom audio and video settings, without dropping down into the world of `AVAssetReader` and `AVAssetWriter`. It has similar capabilites to [SDAVAssetExportSession][SDAV] but the API is completely different, the code is written in Swift, and it's ready for the world of strict concurrency.

You shouldn't have to read through [audio settings][] and [video settings][] just to set the bitrate, and setting the frame rate can be tricky, so there's a nicer API that builds these settings dictionaries with some commonly used settings.

[AV]: https://developer.apple.com/documentation/avfoundation/avassetexportsession
[SDAV]: https://github.com/rs/SDAVAssetExportSession
[audio settings]: https://developer.apple.com/documentation/avfoundation/audio_settings
[video settings]: https://developer.apple.com/documentation/avfoundation/video_settings

## Installation

The only way to install this package is with Swift Package Manager (SPM). Please [file a new issue][] or submit a pull-request if you want to use something else.

[file a new issue]: https://github.com/samsonjs/SJSAssetExportSession/issues/new

### Supported Platforms

This package is supported on iOS 17.0+, macOS Sonoma 14.0+, and visionOS 1.3+.

### Xcode

When you're integrating this into an app with Xcode then go to your project's Package Dependencies and enter the URL `https://github.com/samsonjs/SJSAssetExportSession` and then go through the usual flow for adding packages.

### Swift Package Manager (SPM)

When you're integrating this using SPM on its own then add this to the list of dependencies your Package.swift file:

```swift
.package(url: "https://github.com/samsonjs/SJSAssetExportSession.git", .upToNextMajor(from: "0.3.8"))
```

and then add `"SJSAssetExportSession"` to the list of dependencies in your target as well.

## Usage

There are two ways of exporting assets: one using dictionaries for audio and video settings just like with `SDAVAssetExportSession`, and the other using a builder-like API with data structures for commonly used settings.

### The Nice Way

This should be fairly self-explanatory:

```swift
let sourceURL = URL.documentsDirectory.appending(component: "some-video.mov")
let sourceAsset = AVURLAsset(url: sourceURL, options: [
    AVURLAssetPreferPreciseDurationAndTimingKey: true,
])
let destinationURL = URL.temporaryDirectory.appending(component: "shiny-new-video.mp4")
let exporter = ExportSession()
Task {
    for await progress in exporter.progressStream {
        print("Export progress: \(progress)")
    }
}

try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

Most of the audio and video configuration is optional which is why there are no audio settings specified here. By default you get AAC with 2 channels at a 44.1 KHz sample rate.

### All Nice Parameters

Here are all of the parameters you can pass into the nice export method:

```swift
let sourceURL = URL.documentsDirectory.appending(component: "some-video.mov")
let sourceAsset = AVURLAsset(url: sourceURL, options: [
    AVURLAssetPreferPreciseDurationAndTimingKey: true,
])
let destinationURL = URL.temporaryDirectory.appending(component: "shiny-new-video.mp4")
let exporter = ExportSession()
Task {
    for await progress in exporter.progressStream {
        print("Export progress: \(progress)")
    }
}

let locationMetadata = AVMutableMetadataItem()
locationMetadata.key = AVMetadataKey.commonKeyLocation.rawValue as NSString
locationMetadata.keySpace = .common
locationMetadata.value = "+48.50176+123.34368/" as NSString
try await exporter.export(
    asset: sourceAsset,
    optimizeForNetworkUse: true,
    metadata: [locationMetadata],
    timeRange: CMTimeRange(start: .zero, duration: .seconds(1)),
    audio: .format(.mp3).channels(1).sampleRate(22_050),
    video: .codec(.h264, width: 1280, height: 720)
        .fps(24)
        .bitrate(1_000_000)
        .color(.sdr),
    to: destinationURL,
    as: .mp4
    )
```

### The Most Flexible Way

When you need all the control you can get down to the nitty gritty details. This code does the exact same thing as the code above:

```swift
let sourceURL = URL.documentsDirectory.appending(component: "some-video.mov")
let sourceAsset = AVURLAsset(url: sourceURL, options: [
    AVURLAssetPreferPreciseDurationAndTimingKey: true,
])
let destinationURL = URL.temporaryDirectory.appending(component: "shiny-new-video.mp4")
let exporter = ExportSession()
Task {
    for await progress in exporter.progressStream {
        print("Export progress: \(progress)")
    }
}

let locationMetadata = AVMutableMetadataItem()
locationMetadata.key = AVMetadataKey.commonKeyLocation.rawValue as NSString
locationMetadata.keySpace = .common
locationMetadata.value = "+48.50176+123.34368/" as NSString

let videoComposition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: sourceAsset)
videoComposition.renderSize = CGSize(width: 1280, height: 720)
videoComposition.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
videoComposition.frameDuration = CMTime(value: 600 / 24, timescale: 600) // 24 fps
videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
try await exporter.export(
    asset: sourceAsset,
    optimizeForNetworkUse: true,
    metadata: [locationMetadata],
    timeRange: CMTimeRange(start: .zero, duration: .seconds(1)),
    audioOutputSettings: [
        AVFormatIDKey: kAudioFormatMPEGLayer3,
        AVNumberOfChannelsKey: NSNumber(value: 1),
        AVSampleRateKey: NSNumber(value: 22_050),
    ],
    videoOutputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
        AVVideoCompressionPropertiesKey: [
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoAverageBitRateKey: NSNumber(value: 1_000_000),
        ] as [String: any Sendable],
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
    ],
    composition: videoComposition,
    to: destinationURL,
    as: .mp4
)
```

It's an effective illustration of why the nicer API exists right? But when you need this flexibility then it's available for you.

### Mix and Match

`AudioOutputSettings` and `VideoOutputSettings` have a property named `settingsDictionary` and you can use that to bootstrap your own custom settings.

```swift
let sourceURL = URL.documentsDirectory.appending(component: "some-video.mov")
let sourceAsset = AVURLAsset(url: sourceURL, options: [
    AVURLAssetPreferPreciseDurationAndTimingKey: true,
])
let destinationURL = URL.temporaryDirectory.appending(component: "shiny-new-video.mp4")
let exporter = ExportSession()
Task {
    for await progress in exporter.progressStream {
        print("Export progress: \(progress)")
    }
}

var audioSettings = AudioOutputSettings.default.settingsDictionary
audioSettings[AVVideoAverageBitRateKey] = 65_536
let videoSettings = VideoOutputSettings
    .codec(.hevc, width: 1280, height: 720)
    .settingsDictionary
try await exporter.export(
    asset: sourceAsset,
    audioOutputSettings: audioSettings,
    videoOutputSettings: videoSettings,
    to: destinationURL,
    as: .mp4
)
```

## License

Copyright © 2024 [Sami Samhuri](https://samhuri.net) <sami@samhuri.net>. Released under the terms of the [MIT License][MIT].

[MIT]: https://sjs.mit-license.org
