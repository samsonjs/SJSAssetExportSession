//
//  ReadmeExamples.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2024-08-18.
//

import AVFoundation
import SJSAssetExportSession

private func readmeNiceExample() async throws {
    let sourceURL = URL.documentsDirectory.appending(component: "some-video.mov")
    let sourceAsset = AVURLAsset(url: sourceURL, options: [
        AVURLAssetPreferPreciseDurationAndTimingKey: true,
    ])
    let destinationURL = URL.temporaryDirectory.appending(component: "shiny-new-video.mp4")
    let exporter = ExportSession()
    Task {
        for await progress in exporter.progressStream {
            print("Export progress: \(progress)")
        }
    }

    try await exporter.export(
        asset: sourceAsset,
        video: .codec(.h264, width: 1280, height: 720),
        to: destinationURL,
        as: .mp4
    )
}

private func readmeCompleteNiceExample() async throws {
    let sourceURL = URL.documentsDirectory.appending(component: "some-video.mov")
    let sourceAsset = AVURLAsset(url: sourceURL, options: [
        AVURLAssetPreferPreciseDurationAndTimingKey: true,
    ])
    let destinationURL = URL.temporaryDirectory.appending(component: "shiny-new-video.mp4")
    let exporter = ExportSession()
    Task {
        for await progress in exporter.progressStream {
            print("Export progress: \(progress)")
        }
    }

    let locationMetadata = AVMutableMetadataItem()
    locationMetadata.key = AVMetadataKey.commonKeyLocation.rawValue as NSString
    locationMetadata.keySpace = .common
    locationMetadata.value = "+48.50176+123.34368/" as NSString
    try await exporter.export(
        asset: sourceAsset,
        optimizeForNetworkUse: true,
        metadata: [locationMetadata],
        timeRange: CMTimeRange(start: .zero, duration: .seconds(1)),
        audio: .format(.mp3).channels(1).sampleRate(22_050),
        video: .codec(.h264, width: 1280, height: 720)
            .fps(24)
            .bitrate(1_000_000)
            .color(.sdr),
        to: destinationURL,
        as: .mp4
    )
}

private func readmeFlexibleExample() async throws {
    let sourceURL = URL.documentsDirectory.appending(component: "some-video.mov")
    let sourceAsset = AVURLAsset(url: sourceURL, options: [
        AVURLAssetPreferPreciseDurationAndTimingKey: true,
    ])
    let destinationURL = URL.temporaryDirectory.appending(component: "shiny-new-video.mp4")
    let exporter = ExportSession()
    Task {
        for await progress in exporter.progressStream {
            print("Export progress: \(progress)")
        }
    }

    let locationMetadata = AVMutableMetadataItem()
    locationMetadata.key = AVMetadataKey.commonKeyLocation.rawValue as NSString
    locationMetadata.keySpace = .common
    locationMetadata.value = "+48.50176+123.34368/" as NSString

    let videoComposition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: sourceAsset)
    videoComposition.renderSize = CGSize(width: 1280, height: 720)
    videoComposition.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
    videoComposition.frameDuration = CMTime(value: 600 / 24, timescale: 600) // 24 fps
    videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
    videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
    videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
    try await exporter.export(
        asset: sourceAsset,
        optimizeForNetworkUse: true,
        metadata: [locationMetadata],
        timeRange: CMTimeRange(start: .zero, duration: .seconds(1)),
        audioOutputSettings: [
            AVFormatIDKey: kAudioFormatMPEGLayer3,
            AVNumberOfChannelsKey: NSNumber(value: 1),
            AVSampleRateKey: NSNumber(value: 22_050),
        ],
        videoOutputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
            AVVideoCompressionPropertiesKey: [
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAverageBitRateKey: NSNumber(value: 1_000_000),
            ] as [String: any Sendable],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ],
        composition: videoComposition,
        to: destinationURL,
        as: .mp4
    )
}

private func readmeMixAndMatchExample() async throws {
    let sourceURL = URL.documentsDirectory.appending(component: "some-video.mov")
    let sourceAsset = AVURLAsset(url: sourceURL, options: [
        AVURLAssetPreferPreciseDurationAndTimingKey: true,
    ])
    let destinationURL = URL.temporaryDirectory.appending(component: "shiny-new-video.mp4")
    let exporter = ExportSession()
    Task {
        for await progress in exporter.progressStream {
            print("Export progress: \(progress)")
        }
    }

    var audioSettings = AudioOutputSettings.default.settingsDictionary
    audioSettings[AVVideoAverageBitRateKey] = 65_536
    let videoSettings = VideoOutputSettings
        .codec(.hevc, width: 1280, height: 720)
        .settingsDictionary
    try await exporter.export(
        asset: sourceAsset,
        audioOutputSettings: audioSettings,
        videoOutputSettings: videoSettings,
        to: destinationURL,
        as: .mp4
    )
}
