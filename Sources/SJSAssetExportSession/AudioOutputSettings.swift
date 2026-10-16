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

    public func channels(_ channels: Int) -> AudioOutputSettings {
        .init(format: format, channels: channels, sampleRate: sampleRate)
    }

    public func sampleRate(_ sampleRate: Int?) -> AudioOutputSettings {
        .init(format: format, channels: channels, sampleRate: sampleRate)
    }

    /// The settings for an `AVAssetWriterInput`. More than two channels get the AAC layout for that
    /// many channels, since the writer input raises an exception without one. The AAC encoder writes
    /// its own layout for each channel count whatever layout it's given, so there's no other choice.
    public var settingsDictionary: [String: any Sendable] {
        var settings: [String: any Sendable] = [
            AVFormatIDKey: format,
            AVNumberOfChannelsKey: NSNumber(value: channels),
        ]
        if let sampleRate {
            settings[AVSampleRateKey] = NSNumber(value: Float(sampleRate))
        }
        if let layoutTag = Self.layoutTag(channels: channels) {
            var layout = AudioChannelLayout()
            layout.mChannelLayoutTag = layoutTag
            settings[AVChannelLayoutKey] = Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)
        }
        return settings
    }

    private static func layoutTag(channels: Int) -> AudioChannelLayoutTag? {
        switch channels {
        case 3: kAudioChannelLayoutTag_AAC_3_0
        case 4: kAudioChannelLayoutTag_AAC_Quadraphonic
        case 5: kAudioChannelLayoutTag_AAC_5_0
        case 6: kAudioChannelLayoutTag_AAC_5_1
        case 7: kAudioChannelLayoutTag_AAC_6_1
        case 8: kAudioChannelLayoutTag_AAC_7_1
        default: nil
        }
    }
}
