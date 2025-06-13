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

    public let format: AudioFormatID
    public let channels: Int
    public let sampleRate: Int?

    /// Specifies the AAC format with 2 channels at a 44.1 KHz sample rate.
    public static var `default`: AudioOutputSettings {
        .format(.aac).channels(2).sampleRate(44_100)
    }

    /// Specifies the given format with 2 channels.
    public static func format(_ format: Format) -> AudioOutputSettings {
        .init(format: format.formatID, channels: 2, sampleRate: nil)
    }

    /// Sets the number of output channels.
    ///
    /// - Parameter channels: Number of channels (1 for mono, 2 for stereo, etc.).
    /// - Returns: A new AudioOutputSettings with the specified channel count.
    public func channels(_ channels: Int) -> AudioOutputSettings {
        .init(format: format, channels: channels, sampleRate: sampleRate)
    }

    /// Sets the sample rate in Hz.
    ///
    /// - Parameter sampleRate: Sample rate in Hz, or nil to use default for format.
    /// - Returns: A new AudioOutputSettings with the specified sample rate.
    public func sampleRate(_ sampleRate: Int?) -> AudioOutputSettings {
        .init(format: format, channels: channels, sampleRate: sampleRate)
    }

    /// Converts these settings to an AVFoundation audio settings dictionary.
    ///
    /// - Returns: Dictionary suitable for use with AVAssetWriter.
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
