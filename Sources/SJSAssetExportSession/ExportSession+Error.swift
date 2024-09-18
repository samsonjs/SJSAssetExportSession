//
//  ExportSession+Error.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-07.
//

import Foundation

extension ExportSession {
    public enum SetupFailureReason: String, Sendable, CustomStringConvertible {
        case audioSettingsEmpty
        case audioSettingsInvalid
        case cannotAddAudioInput
        case cannotAddAudioOutput
        case cannotAddVideoInput
        case cannotAddVideoOutput
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
}
