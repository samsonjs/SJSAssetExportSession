//
//  ExportSession.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-06-29.
//

public import AVFoundation


public final class ExportSession: @unchecked Sendable {
    // @unchecked Sendable because progress properties are mutable, it's safe though.

    public typealias ProgressStream = AsyncStream<Float>

    public var progressStream: ProgressStream = ProgressStream(unfolding: { 0.0 })

    private var progressContinuation: ProgressStream.Continuation?

    public init() {
        progressStream = AsyncStream { continuation in
            progressContinuation = continuation
        }
    }

    /**
     Exports the given asset using all of the other parameters to transform it in some way.

     - Parameters:
       - asset: The source asset to export. This can be any kind of `AVAsset` including subclasses such as `AVComposition`.

       - audioMix: An optional mix that can be used to manipulate the audio in some way.

       - audioOutputSettings: Audio settings using [audio settings keys from AVFoundation](https://developer.apple.com/documentation/avfoundation/audio_settings) and values must be suitable for consumption by Objective-C. Required keys are:
         - `AVFormatIDKey` with the typical value `kAudioFormatMPEG4AAC`
         - `AVNumberOfChannelsKey` with the typical value `NSNumber(value: 2)` or `AVChannelLayoutKey` with an instance of `AVAudioChannelLayout`

       - videoComposition: Used to manipulate the video in some way. This can be used to scale the video, apply filters, amongst other edits.

       - videoOutputSettings: Video settings using [video settings keys from AVFoundation](https://developer.apple.com/documentation/avfoundation/video_settings) and values must be suitable for consumption by Objective-C. Required keys are:
          - `AVVideoCodecKey` with the typical value `AVVideoCodecType.h264.rawValue` or `AVVideoCodecType.hevc.rawValue`
          - `AVVideoWidthKey` with an integer as an `NSNumber`
          - `AVVideoHeightKey` with an integer as an `NSNumber`

       - timeRange: Providing a time range exports a subset of the asset instead of the entire duration, which is the default behaviour.

       - optimizeForNetworkUse: Setting this value to `true` writes the output file in a form that enables a player to begin playing the media after downloading only a small portion of it. Defaults to `false`.

       - outputURL: The file URL where the exported video will be written.

       - fileType: The type of of video file to export. This will typically be one of `AVFileType.mp4`, `AVFileType.m4v`, or `AVFileType.mov`.
     */
    public func export(
        asset: sending AVAsset,
        audioMix: sending AVAudioMix?,
        audioOutputSettings: [String: (any Sendable)],
        videoComposition: sending AVVideoComposition,
        videoOutputSettings: [String: (any Sendable)],
        timeRange: CMTimeRange? = nil,
        optimizeForNetworkUse: Bool = false,
        to outputURL: URL,
        as fileType: AVFileType
    ) async throws {
        let sampleWriter = try await SampleWriter(
            asset: asset,
            audioMix: audioMix,
            audioOutputSettings: audioOutputSettings,
            videoComposition: videoComposition,
            videoOutputSettings: videoOutputSettings,
            timeRange: timeRange,
            optimizeForNetworkUse: optimizeForNetworkUse,
            outputURL: outputURL,
            fileType: fileType
        )
        Task { [progressContinuation] in
            for await progress in await sampleWriter.progressStream {
                progressContinuation?.yield(progress)
            }
        }
        try await sampleWriter.writeSamples()
    }
}
