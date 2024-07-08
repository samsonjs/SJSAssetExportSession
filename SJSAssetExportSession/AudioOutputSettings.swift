//
//  AudioSettings.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-07.
//

public import AVFoundation

public struct AudioOutputSettings {
    public enum Format {
        case aac
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

    public static var `default`: AudioOutputSettings {
        .format(.aac).channels(2).sampleRate(44_100)
    }

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

    var settingsDictionary: [String: any Sendable] {
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
