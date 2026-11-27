//
//  ExportSession.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-06-29.
//

public import AVFoundation

public final class ExportSession: Sendable {
    public let progressStream: AsyncStream<Float>

    private let progressContinuation: AsyncStream<Float>.Continuation

    public init() {
        (progressStream, progressContinuation) = AsyncStream<Float>.makeStream()
    }

    /**
     Exports the given asset using all of the other parameters to transform it in some way. This method uses code to build up audio and video settings with a nice API instead of diving into the nitty gritty settings dictionaries. Monitor progress using ``progressStream``.

     - Parameters:
       - asset: The source asset to export. This can be any kind of `AVAsset` including subclasses such as `AVComposition`.

       - optimizeForNetworkUse: Setting this value to `true` writes the output file in a form that enables a player to begin playing the media after downloading only a small portion of it. Defaults to `false`.

       - metadata: Optional array of `AVMetadataItem`s to be written out with the exported asset.

       - timeRange: Providing a time range exports a subset of the asset instead of the entire duration, which is the default behaviour.

       - audio: Optional audio settings using ``AudioOutputSettings``. Defaults to ``AudioOutputSettings/default``.

       - mix: An optional mix that can be used to manipulate the audio in some way. A track's `.varispeed` time pitch algorithm is ignored and AVFoundation's default is used for that track instead, because reading a short cut of time-scaled audio with varispeed never finishes.

       - video: Video settings using ``VideoOutputSettings``.

       - drawFrame: An optional ``FrameArtist`` that draws into each video frame, in place, before it's encoded. See ``FrameArtist`` for when it's called and what it can rely on.

       - outputURL: The file `URL` where the exported video will be written.

       - fileType: The type of of video file to export. This will typically be one of `AVFileType.mp4`, `AVFileType.m4v`, or `AVFileType.mov`.

     - Throws: One of the cases in the ``ExportSession/Error`` enum when the export fails, or the error thrown by `drawFrame`. See ``ExportSession/Error`` for possible failures.
     */
    public func export(
        asset: sending AVAsset,
        optimizeForNetworkUse: Bool = false,
        metadata: sending [AVMetadataItem] = [],
        timeRange: CMTimeRange? = nil,
        audio: sending AudioOutputSettings = .default,
        mix: sending AVAudioMix? = nil,
        video: sending VideoOutputSettings,
        drawFrame: sending FrameArtist? = nil,
        to outputURL: URL,
        as fileType: AVFileType
    ) async throws {
        let videoComposition = try await AVMutableVideoComposition.videoComposition(
            withPropertiesOf: asset
        ).applyingFrameRateAndColour(video)
        let sampleWriter = try await SampleWriter(
            asset: asset,
            audioOutputSettings: audio.settingsDictionary,
            audioMix: mix,
            videoOutputSettings: video.settingsDictionary,
            videoComposition: videoComposition,
            scaleMode: video.scaleMode,
            timeRange: timeRange,
            optimizeForNetworkUse: optimizeForNetworkUse,
            metadata: metadata,
            drawFrame: drawFrame,
            outputURL: outputURL,
            fileType: fileType
        )
        Task { [progressContinuation] in
            for await progress in sampleWriter.progressStream {
                progressContinuation.yield(progress)
            }
        }
        try await sampleWriter.writeSamples()
    }

    /**
     Exports the given asset using all of the other parameters to transform it in some way. This method provides the most control over the export using audio and video settings dictionaries, in addition to an optionial audio mix and optional video composition. Monitor progress using ``progressStream``.

     - Parameters:
       - asset: The source asset to export. This can be any kind of `AVAsset` including subclasses such as `AVComposition`.

       - optimizeForNetworkUse: Setting this value to `true` writes the output file in a form that enables a player to begin playing the media after downloading only a small portion of it. Defaults to `false`.

       - metadata: Optional array of `AVMetadataItem`s to be written out with the exported asset.

       - timeRange: Providing a time range exports a subset of the asset instead of the entire duration, which is the default behaviour.

       - audioOutputSettings: Audio settings using [audio settings keys from AVFoundation](https://developer.apple.com/documentation/avfoundation/audio_settings) and values must be suitable for consumption by Objective-C. Required keys are:
         - `AVFormatIDKey` with the typical value `kAudioFormatMPEG4AAC`
         - `AVNumberOfChannelsKey` with the typical value `NSNumber(value: 2)` or `AVChannelLayoutKey` with an instance of `AVAudioChannelLayout` for use with more than 2 channels.

         Without `AVSampleRateKey` the export uses the sample rate of the source's audio tracks, or 44.1 kHz when they have different rates, lowered to the nearest rate the format can encode when it can't encode that one.

         With `nil`, as with `AVAssetWriterInput`, every audio track is copied without being decoded or encoded again, disabled tracks included, so the output keeps each track's format, channels, sample rate and bitrate. Tracks keep whether they're enabled and their language. Tracks the source groups as alternates, or links with an audio fallback association, are grouped as alternates in the output, and the association is kept. Timed metadata tracks that describe a copied audio track are copied too, such as the `com.apple.quicktime.cinematic-audio` track iPhones write for their spatial audio track. The `fileType` has to be able to hold each track's format, or the export throws ``ExportSession/Error/setupFailure(_:)`` with ``ExportSession/SetupFailureReason/cannotAddAudioInput``.

       - mix: An optional mix that can be used to manipulate the audio in some way. A track's `.varispeed` time pitch algorithm is ignored and AVFoundation's default is used for that track instead, because reading a short cut of time-scaled audio with varispeed never finishes. A mix can't be used when `audioOutputSettings` is `nil`, and the export throws ``ExportSession/Error/setupFailure(_:)`` with ``ExportSession/SetupFailureReason/audioSettingsInvalid`` if one is given.

       - videoOutputSettings: Video settings using [video settings keys from AVFoundation](https://developer.apple.com/documentation/avfoundation/video_settings) and values must be suitable for consumption by Objective-C. Required keys are:
          - `AVVideoCodecKey` with the typical value `AVVideoCodecType.h264.rawValue` or `AVVideoCodecType.hevc.rawValue`
          - `AVVideoWidthKey` with an integer as an `NSNumber`, optional when a video composition is given
          - `AVVideoHeightKey` with an integer as an `NSNumber`, optional when a video composition is given

       - composition: An optional composition that can be used to manipulate the video in some way. This can scale the video, apply filters, or ramp audio volume, amongst other edits. Without one, frames are scaled to fit the size in `videoOutputSettings`. With one, it's used as is and has to do any scaling itself.

       - drawFrame: An optional ``FrameArtist`` that draws into each video frame, in place, before it's encoded. See ``FrameArtist`` for when it's called and what it can rely on.

       - outputURL: The file URL where the exported video will be written.

       - fileType: The type of of video file to export. This will typically be one of `AVFileType.mp4`, `AVFileType.m4v`, or `AVFileType.mov`.

     - Throws: One of the cases in the ``ExportSession/Error`` enum when the export fails, or the error thrown by `drawFrame`. See ``ExportSession/Error`` for possible failures.
     */
    public func export(
        asset: sending AVAsset,
        optimizeForNetworkUse: Bool = false,
        metadata: sending [AVMetadataItem] = [],
        timeRange: CMTimeRange? = nil,
        audioOutputSettings: [String: any Sendable]?,
        mix: sending AVAudioMix? = nil,
        videoOutputSettings: [String: any Sendable],
        composition: sending AVVideoComposition? = nil,
        drawFrame: sending FrameArtist? = nil,
        to outputURL: URL,
        as fileType: AVFileType
    ) async throws {
        // Frames from our own composition come out at the source size and are scaled to fit.
        let scaleMode: VideoOutputSettings.ScaleMode? = composition == nil ? .fit : nil
        let videoComposition: AVVideoComposition = if let composition {
            composition
        } else {
            try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
        }
        var videoOutputSettings = videoOutputSettings
        if videoOutputSettings[AVVideoWidthKey] == nil || videoOutputSettings[AVVideoHeightKey] == nil {
            let size = videoComposition.renderSize
            videoOutputSettings[AVVideoWidthKey] = NSNumber(value: Int(size.width))
            videoOutputSettings[AVVideoHeightKey] = NSNumber(value: Int(size.height))
        }
        let sampleWriter = try await SampleWriter(
            asset: asset,
            audioOutputSettings: audioOutputSettings,
            audioMix: mix,
            videoOutputSettings: videoOutputSettings,
            videoComposition: videoComposition,
            scaleMode: scaleMode,
            timeRange: timeRange,
            optimizeForNetworkUse: optimizeForNetworkUse,
            metadata: metadata,
            drawFrame: drawFrame,
            outputURL: outputURL,
            fileType: fileType
        )
        Task { [progressContinuation] in
            for await progress in sampleWriter.progressStream {
                progressContinuation.yield(progress)
            }
        }
        try await sampleWriter.writeSamples()
    }
}
