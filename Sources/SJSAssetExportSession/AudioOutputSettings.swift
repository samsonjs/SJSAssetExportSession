//
//  AudioSettings.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-07.
//

public import AVFoundation

/// A convenient API for constructing audio settings dictionaries.
///
/// Construct this by starting with ``AudioOutputSettings/default`` or ``AudioOutputSettings/format(_:)`` and then chain calls to further customize it, if desired, using ``channels(_:)``, ``sampleRate(_:)``, and ``mix(_:)``.
public struct AudioOutputSettings {
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
    let mix: AVAudioMix?

    /// Specifies the AAC format with 2 channels at a 44.1 KHz sample rate.
    public static var `default`: AudioOutputSettings {
        .format(.aac).channels(2).sampleRate(44_100)
    }

    /// Specifies the given format with 2 channels.
    public static func format(_ format: Format) -> AudioOutputSettings {
        .init(format: format.formatID, channels: 2, sampleRate: nil, mix: nil)
    }

    public func channels(_ channels: Int) -> AudioOutputSettings {
        .init(format: format, channels: channels, sampleRate: sampleRate, mix: mix)
    }

    public func sampleRate(_ sampleRate: Int?) -> AudioOutputSettings {
        .init(format: format, channels: channels, sampleRate: sampleRate, mix: mix)
    }

    public func mix(_ mix: sending AVAudioMix?) -> AudioOutputSettings {
        .init(format: format, channels: channels, sampleRate: sampleRate, mix: mix)
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
