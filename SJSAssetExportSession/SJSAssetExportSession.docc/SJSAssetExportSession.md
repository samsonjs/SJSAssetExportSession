# ``SJSAssetExportSession``

`SJSAssetExportSession` is an alternative to `AVAssetExportSession` that lets you provide custom audio and video settings, without dropping down into the world of `AVAssetReader` and `AVAssetWriter`.

[`AVAssetExportSession`][AV] is fine for some things but it provides basically no way to customize the export settings, besides the couple of options on `AVVideoComposition` like render size and frame rate. This package has similar capabilites to the venerable [`SDAVAssetExportSession`][SDAV] but the API is completely different, the code is written in Swift, and it's ready for the world of strict concurrency.

You shouldn't have to read through [audio settings][] and [video settings][] just to set the bitrate, and setting the frame rate can be tricky, so there's a nicer API that builds these settings dictionaries with some commonly used settings.

[AV]: https://developer.apple.com/documentation/avfoundation/avassetexportsession
[SDAV]: https://github.com/rs/SDAVAssetExportSession
[audio settings]: https://developer.apple.com/documentation/avfoundation/audio_settings
[video settings]: https://developer.apple.com/documentation/avfoundation/video_settings

The simplest usage is something like this:

```swift
let exporter = ExportSession()
Task {
    for await progress in exporter.progressStream {
        print("Progress: \(progress)")
    }
}
try await exporter.export(
    asset: AVURLAsset(url: sourceURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]),
    video: .codec(.h264, width: 1280, height: 720),
    to: URL.temporaryDirectory.appeding(component: "new-video.mp4"),
    as: .mp4
)
```

## Topics

### Exporting

- ``ExportSession``
- ``ExportSession/Error``
- ``ExportSession/SetupFailureReason``

### Audio Output Settings

- ``AudioOutputSettings``
- ``AudioOutputSettings/Format``

### Video Output Settings

- ``VideoOutputSettings``
- ``VideoOutputSettings/Codec``
- ``VideoOutputSettings/H264Profile``
- ``VideoOutputSettings/Color``
