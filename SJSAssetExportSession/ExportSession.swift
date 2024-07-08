//
//  ExportSession.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-06-29.
//

public import AVFoundation


// @unchecked Sendable because progress properties are mutable, it's safe though.
public final class ExportSession: @unchecked Sendable {
    public enum SetupFailureReason: String, Sendable, CustomStringConvertible {
        case audioSettingsEmpty
        case audioSettingsInvalid
        case cannotAddAudioInput
        case cannotAddAudioOutput
        case cannotAddVideoInput
        case cannotAddVideoOutput
        case videoSettingsEmpty
        case videoSettingsInvalid
        case videoTracksEmpty

        public var description: String {
            switch self {
            case .audioSettingsEmpty:
                "Must provide audio output settings"
            case .audioSettingsInvalid:
                "Invalid audio output settings"
            case .cannotAddAudioInput:
                "Can't add audio input to writer"
            case .cannotAddAudioOutput:
                "Can't add audio output to reader"
            case .cannotAddVideoInput:
                "Can't add video input to writer"
            case .cannotAddVideoOutput:
                "Can't add video output to reader"
            case .videoSettingsEmpty:
                "Must provide video output settings"
            case .videoSettingsInvalid:
                "Invalid video output settings"
            case .videoTracksEmpty:
                "No video track"
            }
        }
    }

    public enum Error: LocalizedError, Equatable {
        case setupFailure(SetupFailureReason)
        case readFailure((any Swift.Error)?)
        case writeFailure((any Swift.Error)?)

        public var errorDescription: String? {
            switch self {
            case let .setupFailure(reason):
                reason.description
            case let .readFailure(underlyingError):
                underlyingError?.localizedDescription ?? "Unknown read failure"
            case let .writeFailure(underlyingError):
                underlyingError?.localizedDescription ?? "Unknown write failure"
            }
        }

        public static func == (lhs: ExportSession.Error, rhs: ExportSession.Error) -> Bool {
            switch (lhs, rhs) {
            case let (.setupFailure(lhsReason), .setupFailure(rhsReason)):
                lhsReason == rhsReason
            case let (.readFailure(lhsError), .readFailure(rhsError)):
                String(describing: lhsError) == String(describing: rhsError)
            case let (.writeFailure(lhsError), .writeFailure(rhsError)):
                String(describing: lhsError) == String(describing: rhsError)
            default:
                false
            }
        }
    }

    public typealias ProgressStream = AsyncStream<Float>

    public var progressStream: ProgressStream = ProgressStream(unfolding: { 0.0 })

    private var progressContinuation: ProgressStream.Continuation?

    public init() {
        progressStream = AsyncStream { continuation in
            progressContinuation = continuation
        }
    }

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
            timeRange: timeRange ?? CMTimeRange(start: .zero, duration: .positiveInfinity),
            audioMix: audioMix,
            audioOutputSettings: audioOutputSettings,
            videoComposition: videoComposition,
            videoOutputSettings: videoOutputSettings,
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
