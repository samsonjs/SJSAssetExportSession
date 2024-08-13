//
//  VideoOutputSettings.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-07.
//

import AVFoundation

public struct VideoOutputSettings {
    public enum H264Profile {
        case baselineAuto, baseline30, baseline31, baseline41
        case mainAuto, main31, main32, main41
        case highAuto, high40, high41

        var level: String {
            switch self {
            case .baselineAuto: AVVideoProfileLevelH264BaselineAutoLevel
            case .baseline30: AVVideoProfileLevelH264Baseline30
            case .baseline31: AVVideoProfileLevelH264Baseline31
            case .baseline41: AVVideoProfileLevelH264Baseline41
            case .mainAuto: AVVideoProfileLevelH264MainAutoLevel
            case .main31: AVVideoProfileLevelH264Main31
            case .main32: AVVideoProfileLevelH264Main32
            case .main41: AVVideoProfileLevelH264Main41
            case .highAuto: AVVideoProfileLevelH264HighAutoLevel
            case .high40: AVVideoProfileLevelH264High40
            case .high41: AVVideoProfileLevelH264High41
            }
        }
    }

    public enum Codec {
        case h264(H264Profile)
        case hevc

        static var h264: Codec {
            .h264(.highAuto)
        }

        var stringValue: String {
            switch self {
            case .h264: AVVideoCodecType.h264.rawValue
            case .hevc: AVVideoCodecType.hevc.rawValue
            }
        }

        var profileLevel: String? {
            switch self {
            case let .h264(profile): profile.level
            case .hevc: nil
            }
        }
    }

    public enum Color {
        case sdr, hdr

        var properties: [String: any Sendable] {
            switch self {
            case .sdr:
                [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
                ]
            case .hdr:
                [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
                ]
            }
        }
    }

    let codec: Codec
    let size: CGSize
    let fps: Int?
    let bitrate: Int?
    let color: Color?

    public static func codec(_ codec: Codec, size: CGSize) -> VideoOutputSettings {
        .init(codec: codec, size: size, fps: nil, bitrate: nil, color: nil)
    }

    public static func codec(_ codec: Codec, width: Int, height: Int) -> VideoOutputSettings {
        .codec(codec, size: CGSize(width: width, height: height))
    }

    public func fps(_ fps: Int?) -> VideoOutputSettings {
        .init(codec: codec, size: size, fps: fps, bitrate: bitrate, color: color)
    }

    public func bitrate(_ bitrate: Int?) -> VideoOutputSettings {
        .init(codec: codec, size: size, fps: fps, bitrate: bitrate, color: color)
    }

    public func color(_ color: Color?) -> VideoOutputSettings {
        .init(codec: codec, size: size, fps: fps, bitrate: bitrate, color: color)
    }

    var settingsDictionary: [String: any Sendable] {
        var result: [String: any Sendable] = [
            AVVideoCodecKey: codec.stringValue,
            AVVideoWidthKey: NSNumber(value: Int(size.width)),
            AVVideoHeightKey: NSNumber(value: Int(size.height)),
        ]
        var compressionDict: [String: any Sendable] = [:]
        if let profileLevel = codec.profileLevel {
            compressionDict[AVVideoProfileLevelKey] = profileLevel
        }
        if let bitrate {
            compressionDict[AVVideoAverageBitRateKey] = NSNumber(value: bitrate)
        }
        if !compressionDict.isEmpty {
            result[AVVideoCompressionPropertiesKey] = compressionDict
        }
        if let color {
            result[AVVideoColorPropertiesKey] = color.properties
        }
        return result
    }
}

extension AVMutableVideoComposition {
    func applyingSettings(_ settings: VideoOutputSettings) -> AVMutableVideoComposition {
        renderSize = settings.size
        if let fps = settings.fps {
            sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
            frameDuration = CMTime(seconds: 1.0 / Double(fps), preferredTimescale: 600)
        }
        switch settings.color {
        case nil: break
        case .sdr:
            colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
            colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
            colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        case .hdr:
            colorPrimaries = AVVideoColorPrimaries_ITU_R_2020
            colorTransferFunction = AVVideoTransferFunction_ITU_R_2100_HLG
            colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_2020
        }
        return self
    }
}
