//
//  VideoOutputSettings.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-07.
//

import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import VideoToolbox

/// A convenient API for constructing video settings dictionaries.
///
/// Construct this by starting with ``VideoOutputSettings/codec(_:size:)`` or ``VideoOutputSettings/codec(_:width:height:)`` and then chaining calls to further customize it, if desired, using ``fps(_:)``, ``bitrate(_:)``, and ``color(_:)``.
///
/// Setting the fps and colour also needs support from the `AVVideoComposition` and these settings can be applied to them with ``VideoOutputSettings/apply(to:)``.
public struct VideoOutputSettings: Hashable, Sendable, Codable {
    /// Describes an H.264 encoding profile.
    public enum H264Profile: Hashable, Sendable, Codable {
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

    /// Specifies the output codec.
    public enum Codec: Hashable, Sendable, Codable {
        /// H.264 using the associated encoding profile.
        case h264(H264Profile)
        /// HEVC / H.265
        case hevc

        /// Construct Codec.h264 using the default profile `H264Profile.highAuto`.
        public static var h264: Codec {
            .h264(.highAuto)
        }

        var stringValue: String {
            switch self {
            case .h264: AVVideoCodecType.h264.rawValue
            case .hevc: AVVideoCodecType.hevc.rawValue
            }
        }

        /// Without a profile, HEVC's bit depth depends on the platform: the iOS encoder writes
        /// 8 bits even from 10-bit frames with HDR colour properties, and the macOS encoder
        /// writes 10 bits from 10-bit frames even with SDR ones.
        func profileLevel(color: Color?) -> String? {
            switch (self, color) {
            case let (.h264(profile), _): profile.level
            case (.hevc, .hdr): kVTProfileLevel_HEVC_Main10_AutoLevel as String
            case (.hevc, .sdr): kVTProfileLevel_HEVC_Main_AutoLevel as String
            case (.hevc, nil): nil
            }
        }
    }

    /// Specifies whether to use Standard Dynamic Range or High Dynamic Range colours.
    public enum Color: Hashable, Sendable, Codable {
        /// Standard dynamic range colours (BT.709 which roughly corresponds to SRGB)
        case sdr
        /// High dynamic range colours (BT.2020)
        case hdr

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

    public let codec: Codec
    public let size: CGSize
    public let fps: Int?
    public let bitrate: Int?
    public let color: Color?

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

    public var settingsDictionary: [String: any Sendable] {
        var result: [String: any Sendable] = [
            AVVideoCodecKey: codec.stringValue,
            AVVideoWidthKey: NSNumber(value: Int(size.width)),
            AVVideoHeightKey: NSNumber(value: Int(size.height)),
        ]
        var compressionDict: [String: any Sendable] = [:]
        if let profileLevel = codec.profileLevel(color: color) {
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

    /// Applies the subset of relevant settings to the given video composition, namely fps and colour.
    public func apply(to videoComposition: AVMutableVideoComposition) {
        _ = videoComposition.applyingSettings(self)
    }
}

extension AVMutableVideoComposition {
    static func videoComposition(
        for asset: AVAsset,
        settings: VideoOutputSettings
    ) async throws -> AVMutableVideoComposition {
        let base = try await videoComposition(withPropertiesOf: asset)
        let target = settings.size
        guard base.renderSize != target, base.renderSize.width > 0, base.renderSize.height > 0 else {
            return base.applyingSettings(settings)
        }
        let composition = try await videoComposition(with: asset) { request in
            let source = request.sourceImage
            let extent = source.extent
            let scaleY = target.height / extent.height
            let scaleX = target.width / extent.width
            let filter = CIFilter.bicubicScaleTransform()
            filter.inputImage = source
            filter.scale = Float(scaleY)
            filter.aspectRatio = Float(scaleX / scaleY)
            let scaled = (filter.outputImage ?? source)
                .transformed(by: CGAffineTransform(translationX: -extent.minX * scaleX, y: -extent.minY * scaleY))
                .cropped(to: CGRect(origin: .zero, size: target))
            request.finish(with: scaled, context: nil)
        }
        composition.renderSize = target
        return composition.applyingSettings(settings)
    }

    func applyingSettings(_ settings: VideoOutputSettings) -> AVMutableVideoComposition {
        if renderSize != settings.size, renderSize.width > 0, renderSize.height > 0 {
            let scale = CGAffineTransform(
                scaleX: settings.size.width / renderSize.width,
                y: settings.size.height / renderSize.height
            )
            
            instructions = instructions.map { instruction in
                guard let instruction = instruction as? AVVideoCompositionInstruction,
                      let scaled = instruction.mutableCopy() as? AVMutableVideoCompositionInstruction
                else { return instruction }
                scaled.layerInstructions = instruction.layerInstructions.map { layer in
                    var start = CGAffineTransform.identity
                    var end = CGAffineTransform.identity
					guard layer.getTransformRamp(for: instruction.timeRange.start, start: &start, end: &end, timeRange: nil) else {
						return layer
					}
                    let scaledLayer = AVMutableVideoCompositionLayerInstruction()
                    scaledLayer.trackID = layer.trackID
					scaledLayer.setTransformRamp(fromStart: start.concatenating(scale), toEnd: end.concatenating(scale), timeRange: instruction.timeRange)
                    return scaledLayer
                }
                return scaled
            }
        }
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
