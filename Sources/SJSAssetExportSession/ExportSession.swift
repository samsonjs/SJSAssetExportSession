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

       - mix: An optional mix that can be used to manipulate the audio in some way.

       - video: Video settings using ``VideoOutputSettings``.

       - outputURL: The file `URL` where the exported video will be written.

       - fileType: The type of of video file to export. This will typically be one of `AVFileType.mp4`, `AVFileType.m4v`, or `AVFileType.mov`.

     - Throws: One of the cases in the ``ExportSession/Error`` enum when the export fails. See ``ExportSession/Error`` for possible failures.
     */
    public func export(
        asset: sending AVAsset,
        optimizeForNetworkUse: Bool = false,
        metadata: sending [AVMetadataItem] = [],
        timeRange: CMTimeRange? = nil,
        audio: sending AudioOutputSettings = .default,
        mix: sending AVAudioMix? = nil,
        video: sending VideoOutputSettings,
        to outputURL: URL,
        as fileType: AVFileType
    ) async throws {
        let videoComposition = try await AVMutableVideoComposition.videoComposition(
            withPropertiesOf: asset
        ).applyingSettings(video)
        let sampleWriter = try await SampleWriter(
            asset: asset,
            audioOutputSettings: audio.settingsDictionary,
            audioMix: mix,
            videoOutputSettings: video.settingsDictionary,
            videoComposition: videoComposition,
            timeRange: timeRange,
            optimizeForNetworkUse: optimizeForNetworkUse,
            metadata: metadata,
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

       - mix: An optional mix that can be used to manipulate the audio in some way.

       - videoOutputSettings: Video settings using [video settings keys from AVFoundation](https://developer.apple.com/documentation/avfoundation/video_settings) and values must be suitable for consumption by Objective-C. Required keys are:
          - `AVVideoCodecKey` with the typical value `AVVideoCodecType.h264.rawValue` or `AVVideoCodecType.hevc.rawValue`
          - `AVVideoWidthKey` with an integer as an `NSNumber`, optional when a video composition is given
          - `AVVideoHeightKey` with an integer as an `NSNumber`, optional when a video composition is given

       - composition: An optional composition that can be used to manipulate the video in some way. This can scale the video, apply filters, or ramp audio volume, amongst other edits.

       - outputURL: The file URL where the exported video will be written.

       - fileType: The type of of video file to export. This will typically be one of `AVFileType.mp4`, `AVFileType.m4v`, or `AVFileType.mov`.

     - Throws: One of the cases in the ``ExportSession/Error`` enum when the export fails. See ``ExportSession/Error`` for possible failures.
     */
    public func export(
        asset: sending AVAsset,
        optimizeForNetworkUse: Bool = false,
        metadata: sending [AVMetadataItem] = [],
        timeRange: CMTimeRange? = nil,
        audioOutputSettings: [String: any Sendable],
        mix: sending AVAudioMix? = nil,
        videoOutputSettings: [String: any Sendable],
        composition: sending AVVideoComposition? = nil,
        to outputURL: URL,
        as fileType: AVFileType
    ) async throws {
        let videoComposition: AVVideoComposition =
        if let composition { composition }
        else if let width = (videoOutputSettings[AVVideoWidthKey] as? NSNumber)?.intValue,
                let height = (videoOutputSettings[AVVideoHeightKey] as? NSNumber)?.intValue
        {
            try await AVMutableVideoComposition.videoComposition(
                withPropertiesOf: asset
            ).applyingSettings(.codec(.h264, width: width, height: height))
        } else {
            try await AVMutableVideoComposition.videoComposition(
                withPropertiesOf: asset
            )
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
            timeRange: timeRange,
            optimizeForNetworkUse: optimizeForNetworkUse,
            metadata: metadata,
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
