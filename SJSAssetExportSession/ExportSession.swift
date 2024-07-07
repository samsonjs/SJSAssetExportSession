//
//  ExportSession.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-06-29.
//

public import AVFoundation

public final class ExportSession {
    public enum Error: LocalizedError {
        case setupFailure(reason: String)
        case readFailure((any Swift.Error)?)
        case writeFailure((any Swift.Error)?)

        public var errorDescription: String? {
            switch self {
            case let .setupFailure(reason):
                reason
            case let .readFailure(underlyingError):
                underlyingError?.localizedDescription ?? "Unknown read failure"
            case let .writeFailure(underlyingError):
                underlyingError?.localizedDescription ?? "Unknown write failure"
            }
        }
    }

    public static func export(
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
            timeRange: timeRange ?? CMTimeRange(start: .zero, duration: .positiveInfinity),
            audioMix: audioMix,
            audioOutputSettings: audioOutputSettings,
            videoComposition: videoComposition,
            videoOutputSettings: videoOutputSettings,
            optimizeForNetworkUse: optimizeForNetworkUse,
            outputURL: outputURL,
            fileType: fileType
        )
        try await sampleWriter.writeSamples()
    }
}
