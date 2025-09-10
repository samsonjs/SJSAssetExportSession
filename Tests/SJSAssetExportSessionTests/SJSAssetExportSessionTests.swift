//
//  SJSAssetExportSessionTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2024-06-29.
//

import AVFoundation
import CoreLocation
import SJSAssetExportSession
import Testing

final class ExportSessionTests: BaseTests {
    @Test func test_sugary_export_720p_h264_24fps() async throws {
        let sourceURL = resourceURL(named: "test-4k-hdr-hevc-30fps.mov")
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            timeRange: CMTimeRange(start: .zero, duration: .seconds(1)),
            video: .codec(.h264, width: 1280, height: 720)
                .fps(24)
                .bitrate(1_000_000)
                .color(.sdr),
            to: destinationURL.url,
            as: .mp4
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        #expect(try await exportedAsset.load(.duration) == .seconds(1))
        // Audio
        try #require(try await exportedAsset.loadTracks(withMediaType: .audio).count == 1)
        let audioTrack = try #require(await exportedAsset.loadTracks(withMediaType: .audio).first)
        let audioFormat = try #require(await audioTrack.load(.formatDescriptions).first)
        #expect(audioFormat.mediaType == .audio)
        #expect(audioFormat.mediaSubType == .mpeg4AAC)
        #expect(audioFormat.audioChannelLayout?.numberOfChannels == 2)
        #expect(audioFormat.audioStreamBasicDescription?.mSampleRate == 44_100)
        // Video
        try #require(await exportedAsset.loadTracks(withMediaType: .video).count == 1)
        let videoTrack = try #require(await exportedAsset.loadTracks(withMediaType: .video).first)
        #expect(try await videoTrack.load(.naturalSize) == CGSize(width: 1280, height: 720))
        #expect(try await videoTrack.load(.nominalFrameRate) == 24.0)
        let dataRate = try await videoTrack.load(.estimatedDataRate)
        #expect((900_000 ... 1_130_000).contains(dataRate))
        let videoFormat = try #require(await videoTrack.load(.formatDescriptions).first)
        #expect(videoFormat.mediaType == .video)
        #expect(videoFormat.mediaSubType == .h264)
        #expect(videoFormat.extensions[.colorPrimaries] == .colorPrimaries(.itu_R_709_2))
        #expect(videoFormat.extensions[.transferFunction] == .transferFunction(.itu_R_709_2))
        #expect(videoFormat.extensions[.yCbCrMatrix] == .yCbCrMatrix(.itu_R_709_2))
    }

    @Test func test_export_720p_h264_24fps() async throws {
        let sourceURL = resourceURL(named: "test-4k-hdr-hevc-30fps.mov")
        let videoComposition = try await makeVideoComposition(
            assetURL: sourceURL,
            size: CGSize(width: 1280, height: 720),
            fps: 24
        )
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            timeRange: CMTimeRange(start: .zero, duration: .seconds(1)),
            audioOutputSettings: AudioOutputSettings.default.settingsDictionary,
            videoOutputSettings: VideoOutputSettings.codec(.h264, width: 1280, height: 720)
                .fps(24)
                .bitrate(1_000_000)
                .color(.sdr)
                .settingsDictionary,
            composition: videoComposition,
            to: destinationURL.url,
            as: .mp4
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        #expect(try await exportedAsset.load(.duration) == .seconds(1))
        // Audio
        try #require(try await exportedAsset.loadTracks(withMediaType: .audio).count == 1)
        let audioTrack = try #require(await exportedAsset.loadTracks(withMediaType: .audio).first)
        let audioFormat = try #require(await audioTrack.load(.formatDescriptions).first)
        #expect(audioFormat.mediaType == .audio)
        #expect(audioFormat.mediaSubType == .mpeg4AAC)
        #expect(audioFormat.audioChannelLayout?.numberOfChannels == 2)
        #expect(audioFormat.audioStreamBasicDescription?.mSampleRate == 44_100)
        // Video
        try #require(await exportedAsset.loadTracks(withMediaType: .video).count == 1)
        let videoTrack = try #require(await exportedAsset.loadTracks(withMediaType: .video).first)
        #expect(try await videoTrack.load(.naturalSize) == CGSize(width: 1280, height: 720))
        #expect(try await videoTrack.load(.nominalFrameRate) == 24.0)
        let dataRate = try await videoTrack.load(.estimatedDataRate)
        #expect((900_000 ... 1_130_000).contains(dataRate))
        let videoFormat = try #require(await videoTrack.load(.formatDescriptions).first)
        #expect(videoFormat.mediaType == .video)
        #expect(videoFormat.mediaSubType == .h264)
        #expect(videoFormat.extensions[.colorPrimaries] == .colorPrimaries(.itu_R_709_2))
        #expect(videoFormat.extensions[.transferFunction] == .transferFunction(.itu_R_709_2))
        #expect(videoFormat.extensions[.yCbCrMatrix] == .yCbCrMatrix(.itu_R_709_2))
    }

    @Test func test_export_default_time_range() async throws {
        let sourceURL = resourceURL(named: "test-720p-h264-24fps.mov")
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            video: .codec(.h264, size: CGSize(width: 1280, height: 720)),
            to: destinationURL.url,
            as: .mov
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        #expect(try await exportedAsset.load(.duration) == .seconds(1))
    }

    @Test func test_export_default_composition_with_size() async throws {
        let sourceURL = resourceURL(named: "test-720p-h264-24fps.mov")
        let size = CGSize(width: 640, height: 360)
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            audioOutputSettings: AudioOutputSettings.default.settingsDictionary,
            videoOutputSettings: VideoOutputSettings.codec(.h264, size: size).settingsDictionary,
            to: destinationURL.url,
            as: .mov
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        let videoTrack = try #require(try await exportedAsset.loadTracks(withMediaType: .video).first)
        #expect(try await videoTrack.load(.naturalSize) == size)
    }

    @Test func test_export_default_composition_without_size() async throws {
        let sourceURL = resourceURL(named: "test-720p-h264-24fps.mov")
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            audioOutputSettings: AudioOutputSettings.default.settingsDictionary,
            videoOutputSettings: [AVVideoCodecKey: AVVideoCodecType.h264.rawValue],
            to: destinationURL.url,
            as: .mov
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        let exportedTrack = try #require(try await exportedAsset.loadTracks(withMediaType: .video).first)
        #expect(try await exportedTrack.load(.naturalSize) == CGSize(width: 1280, height: 720))
    }

    @Test func test_export_x264_60fps() async throws {
        let sourceURL = resourceURL(named: "test-x264-1080p-h264-60fps.mp4")
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            video: .codec(.h264, width: 1920, height: 1080)
                .bitrate(2_500_000)
                .fps(30),
            to: destinationURL.url,
            as: .mp4
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        let videoTrack = try #require(await exportedAsset.loadTracks(withMediaType: .video).first)
        let naturalSize = try await videoTrack.load(.naturalSize)
        #expect(naturalSize == CGSize(width: 1920, height: 1080))
        let fps = try await videoTrack.load(.nominalFrameRate)
        #expect(Int(fps.rounded()) == 30)
        let dataRate = try await videoTrack.load(.estimatedDataRate)
        #expect((2_400_000 ... 2_700_000).contains(dataRate))
        let videoFormat = try #require(await videoTrack.load(.formatDescriptions).first)
        #expect(videoFormat.mediaType == .video)
        #expect(videoFormat.mediaSubType == .h264)
        #expect(videoFormat.extensions[.colorPrimaries] == .colorPrimaries(.itu_R_709_2))
        #expect(videoFormat.extensions[.transferFunction] == .transferFunction(.itu_R_709_2))
        #expect(videoFormat.extensions[.yCbCrMatrix] == .yCbCrMatrix(.itu_R_709_2))
    }

    @Test func test_export_progress() async throws {
        let sourceURL = resourceURL(named: "test-720p-h264-24fps.mov")
        let progressValues = SendableWrapper<[Float]>([])

        let subject = ExportSession()
        Task {
            for await progress in subject.progressStream {
                progressValues.value.append(progress)
            }
        }
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            video: .codec(.h264, width: 1280, height: 720),
            to: makeTemporaryURL().url,
            as: .mov
        )

        // Wait for last progress value to be yielded.
        try await Task.sleep(for: .milliseconds(10))
        #expect(progressValues.value.count > 2, "There should be intermediate progress updates")
        #expect(progressValues.value.first == 0.0)
        #expect(progressValues.value.last == 1.0)
    }

    @Test func test_export_works_with_no_audio() async throws {
        let sourceURL = resourceURL(named: "test-no-audio.mp4")
        let videoComposition = try await makeVideoComposition(assetURL: sourceURL)

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            audioOutputSettings: [:], // Ensure that empty audio settings don't matter w/ no track
            videoOutputSettings: VideoOutputSettings
                .codec(.h264, size: videoComposition.renderSize).settingsDictionary,
            composition: videoComposition,
            to: makeTemporaryURL().url,
            as: .mov
        )
    }

    @Test func test_export_throws_with_empty_audio_settings() async throws {
        try await #require(throws: ExportSession.Error.setupFailure(.audioSettingsEmpty)) {
            let sourceURL = self.resourceURL(named: "test-720p-h264-24fps.mov")
            let videoComposition = try await self.makeVideoComposition(assetURL: sourceURL)

            let subject = ExportSession()
            try await subject.export(
                asset: self.makeAsset(url: sourceURL),
                audioOutputSettings: [:], // Here it matters because there's an audio track
                videoOutputSettings: VideoOutputSettings
                    .codec(.h264, size:  videoComposition.renderSize).settingsDictionary,
                composition: videoComposition,
                to: self.makeTemporaryURL().url,
                as: .mov
            )
        }
    }

    @Test func test_export_throws_with_invalid_audio_settings() async throws {
        try await #require(throws: ExportSession.Error.setupFailure(.audioSettingsInvalid)) {
            let sourceURL = self.resourceURL(named: "test-720p-h264-24fps.mov")

            let subject = ExportSession()
            try await subject.export(
                asset: self.makeAsset(url: sourceURL),
                audioOutputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: NSNumber(value: -1), // invalid number of channels
                ],
                videoOutputSettings: VideoOutputSettings
                    .codec(.h264, size: CGSize(width: 1280, height: 720)).settingsDictionary,
                to: self.makeTemporaryURL().url,
                as: .mov
            )
        }
    }

    @Test func test_export_throws_with_invalid_video_settings() async throws {
        try await #require(throws: ExportSession.Error.setupFailure(.videoSettingsInvalid)) {
            let sourceURL = self.resourceURL(named: "test-720p-h264-24fps.mov")
            let size = CGSize(width: 1280, height: 720)

            let subject = ExportSession()
            try await subject.export(
                asset: self.makeAsset(url: sourceURL),
                audioOutputSettings: AudioOutputSettings.default.settingsDictionary,
                videoOutputSettings: [
                    // missing codec
                    AVVideoWidthKey: NSNumber(value: Int(size.width)),
                    AVVideoHeightKey: NSNumber(value: Int(size.height)),
                ],
                composition: nil,
                to: self.makeTemporaryURL().url,
                as: .mov
            )
        }
    }

    @Test func test_export_throws_with_no_video_track() async throws {
        try await #require(throws: ExportSession.Error.setupFailure(.videoTracksEmpty)) {
            let sourceURL = self.resourceURL(named: "test-no-video.m4a")
            let subject = ExportSession()
            try await subject.export(
                asset: self.makeAsset(url: sourceURL),
                video: .codec(.h264, width: 1280, height: 720),
                to: self.makeTemporaryURL().url,
                as: .mov
            )
        }
    }

    @Test func test_export_cancellation() async throws {
        let sourceURL = resourceURL(named: "test-720p-h264-24fps.mov")
        let destinationURL💥 = makeTemporaryURL()
        let subject = ExportSession()
        let task = Task {
            let sourceAsset = AVURLAsset(url: sourceURL, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true,
            ])
            try await subject.export(
                asset: sourceAsset,
                video: .codec(.h264, width: 1280, height: 720),
                to: destinationURL💥.url,
                as: .mov
            )
            Issue.record("Task should be cancelled long before we get here")
        }
        NSLog("Waiting for encoding to begin...")
        for await progress in subject.progressStream where progress > 0 {
            break
        }
        NSLog("Cancelling task")
        task.cancel()
        try? await task.value // Wait for task to complete
        NSLog("Task has finished executing")
    }

    @Test func test_writing_metadata() async throws {
        let sourceURL = resourceURL(named: "test-720p-h264-24fps.mov")
        let destinationURL = makeTemporaryURL()
        let locationMetadata = AVMutableMetadataItem()
        locationMetadata.key = AVMetadataKey.commonKeyLocation.rawValue as NSString
        locationMetadata.keySpace = .common
        locationMetadata.value = "+48.50176+123.34368/" as NSString

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            metadata: [locationMetadata],
            video: .codec(.h264, size: CGSize(width: 1280, height: 720)),
            to: destinationURL.url,
            as: .mov
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        let exportedMetadata = try await exportedAsset.load(.metadata)
        print(exportedMetadata)
        #expect(exportedMetadata.count == 1)
        let metadataValue = try await exportedMetadata.first(where: { item in
            item.key as! String == AVMetadataKey.quickTimeMetadataKeyLocationISO6709.rawValue
        })?.load(.value) as? NSString
        #expect(metadataValue == "+48.50176+123.34368/")

        let exportedCommonMetadata = try await exportedAsset.load(.commonMetadata)
        print(exportedCommonMetadata)
        #expect(exportedCommonMetadata.count == 1)
        let commonMetadataValue = try await exportedCommonMetadata.first(where: { item in
            item.commonKey == .commonKeyLocation
        })?.load(.value) as? NSString
        #expect(commonMetadataValue == "+48.50176+123.34368/")
    }

    @Test func test_works_with_spatial_audio_track() async throws {
        let sourceURL = resourceURL(named: "test-spatial-audio.mov")
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            video: .codec(.h264, size: CGSize(width: 720, height: 1280)),
            to: destinationURL.url,
            as: .mp4
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        let audioTracks = try await exportedAsset.loadTracks(withMediaType: .audio)
        #expect(audioTracks.count == 1)
    }
}
