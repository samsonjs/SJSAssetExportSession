//
//  AudioSettings.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-07.
//

import AVFoundation

/// A convenient API for constructing audio settings dictionaries.
///
/// Construct this by starting with ``AudioOutputSettings/default`` or ``AudioOutputSettings/format(_:)`` and then chain calls to further customize it, if desired, using ``channels(_:)``, and ``sampleRate(_:)``.
public struct AudioOutputSettings: Hashable, Sendable, Codable {
    /// Describes the output file format.
    public enum Format {
        /// Advanced Audio Codec. The audio format typically used for MPEG-4 audio.
        case aac
        /// The MPEG Layer 3 audio format.
        case mp3

        var formatID: AudioFormatID {
            switch self {
            case .aac: kAudioFormatMPEG4AAC
            case .mp3: kAudioFormatMPEGLayer3
            }
        }
    }

    let format: AudioFormatID
    let channels: Int
    let sampleRate: Int?

    /// Specifies the AAC format with 2 channels at a 44.1 KHz sample rate.
    public static var `default`: AudioOutputSettings {
        .format(.aac).channels(2).sampleRate(44_100)
    }

    /// Specifies the given format with 2 channels.
    public static func format(_ format: Format) -> AudioOutputSettings {
        .init(format: format.formatID, channels: 2, sampleRate: nil)
    }

    public func channels(_ channels: Int) -> AudioOutputSettings {
        .init(format: format, channels: channels, sampleRate: sampleRate)
    }

    public func sampleRate(_ sampleRate: Int?) -> AudioOutputSettings {
        .init(format: format, channels: channels, sampleRate: sampleRate)
    }

    public var settingsDictionary: [String: any Sendable] {
        if let sampleRate {
            [
                AVFormatIDKey: format,
                AVNumberOfChannelsKey: NSNumber(value: channels),
                AVSampleRateKey: NSNumber(value: Float(sampleRate)),
            ]
        } else {
            [
                AVFormatIDKey: format,
                AVNumberOfChannelsKey: NSNumber(value: channels),
            ]
        }
    }
}
