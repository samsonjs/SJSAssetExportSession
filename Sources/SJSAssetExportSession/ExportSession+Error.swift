//
//  ExportSession+Error.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-07.
//

import Foundation

extension ExportSession {
    /// Specific reasons why export setup can fail.
    public enum SetupFailureReason: String, Sendable, CustomStringConvertible {
        /// Audio settings were required but not provided.
        case audioSettingsEmpty
        /// The provided audio settings are invalid or unsupported.
        case audioSettingsInvalid
        /// Could not add audio input to the asset writer.
        case cannotAddAudioInput
        /// Could not add audio output to the asset reader.
        case cannotAddAudioOutput
        /// Could not add video input to the asset writer.
        case cannotAddVideoInput
        /// Could not add video output to the asset reader.
        case cannotAddVideoOutput
        /// The provided video settings are invalid or unsupported.
        case videoSettingsInvalid
        /// The source asset has no video tracks to export.
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
            case .videoSettingsInvalid:
                "Invalid video output settings"
            case .videoTracksEmpty:
                "No video track"
            }
        }
    }

    /// Errors that can occur during export operations.
    public enum Error: LocalizedError, Equatable {
        /// Export failed during initial setup phase.
        case setupFailure(SetupFailureReason)
        /// Export failed while reading from the source asset.
        case readFailure((any Swift.Error)?)
        /// Export failed while writing to the destination file.
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
}
