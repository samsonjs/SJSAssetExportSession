//
//  AudioPassthroughTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2026-11-27.
//

import AVFoundation
import SJSAssetExportSession
import Testing

final class AudioPassthroughTests: BaseTests {
    private let videoSettings = VideoOutputSettings
        .codec(.h264, size: CGSize(width: 720, height: 1280))
        .settingsDictionary

    @Test func test_copies_every_audio_track_as_it_is() async throws {
        let sourceURL = resourceURL(named: "test-spatial-audio.mov")
        let destinationURL = makeTemporaryURL()

        try await ExportSession().export(
            asset: makeAsset(url: sourceURL),
            audioOutputSettings: nil,
            videoOutputSettings: videoSettings,
            to: destinationURL.url,
            as: .mp4
        )

        let source = try await AudioTrackSummary.all(in: sourceURL)
        let exported = try await AudioTrackSummary.all(in: destinationURL.url)
        #expect(source.map(\.subType) == [kAudioFormatMPEG4AAC, kAudioFormatAPAC])
        #expect(exported.map(\.subType) == source.map(\.subType))
        #expect(exported.map(\.channels) == [2, 4])
        #expect(exported.map(\.sampleRate) == [48_000, 48_000])
        #expect(exported.map(\.isEnabled) == [true, false])
        #expect(exported.map(\.packetBytes) == source.map(\.packetBytes))
        #expect(exported.map(\.packetCount) == source.map(\.packetCount))
    }

    @Test func test_keeps_audio_tracks_grouped_as_alternates() async throws {
        let sourceURL = resourceURL(named: "test-spatial-audio.mov")
        let destinationURL = makeTemporaryURL()

        try await ExportSession().export(
            asset: makeAsset(url: sourceURL),
            audioOutputSettings: nil,
            videoOutputSettings: videoSettings,
            to: destinationURL.url,
            as: .mp4
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        let audioTrackIDs = try await exportedAsset.loadTracks(withMediaType: .audio).map(\.trackID)
        let groups = try await exportedAsset.load(.trackGroups).map { Set($0.trackIDs.map(\.int32Value)) }
        #expect(groups == [Set(audioTrackIDs)])
    }

    @Test func test_keeps_the_audio_fallback_association() async throws {
        let sourceURL = resourceURL(named: "test-spatial-audio.mov")
        let destinationURL = makeTemporaryURL()

        try await ExportSession().export(
            asset: makeAsset(url: sourceURL),
            audioOutputSettings: nil,
            videoOutputSettings: videoSettings,
            to: destinationURL.url,
            as: .mp4
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        let audioTracks = try await exportedAsset.loadTracks(withMediaType: .audio)
        try #require(audioTracks.count == 2)
        let fallbacks = try await audioTracks[1].loadAssociatedTracks(ofType: .audioFallback)
        #expect(fallbacks.map(\.trackID) == [audioTracks[0].trackID])
    }

    @Test func test_keeps_the_metadata_that_describes_an_audio_track() async throws {
        // iPhone originals say which track the cinematic-audio metadata describes, but this file doesn't, so a
        // composition says it.
        let source = makeAsset(url: resourceURL(named: "test-spatial-audio.mov"))
        let duration = try await source.load(.duration)
        let composition = AVMutableComposition()
        var compositionTracks: [CMPersistentTrackID: AVMutableCompositionTrack] = [:]
        for sourceTrack in try await source.load(.tracks) {
            let track = try #require(composition.addMutableTrack(
                withMediaType: sourceTrack.mediaType,
                preferredTrackID: sourceTrack.trackID
            ))
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceTrack, at: .zero)
            track.isEnabled = try await sourceTrack.load(.isEnabled)
            compositionTracks[sourceTrack.trackID] = track
        }
        // Track 3 is the spatial audio track and track 5 holds the cinematic-audio metadata.
        let spatial = try #require(compositionTracks[3])
        try #require(compositionTracks[5]).addTrackAssociation(to: spatial, type: .metadataReferent)
        let destinationURL = makeTemporaryURL()

        try await ExportSession().export(
            asset: composition,
            audioOutputSettings: nil,
            videoOutputSettings: videoSettings,
            to: destinationURL.url,
            as: .mp4
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        let spatialTrack = try #require(await exportedAsset.loadTracks(withMediaType: .audio).last)
        let metadataTracks = try await exportedAsset.loadTracks(withMediaType: .metadata)
        try #require(metadataTracks.count == 1)
        let identifiers = try await metadataTracks[0].load(.formatDescriptions).flatMap { format in
            CMMetadataFormatDescriptionGetIdentifiers(format) as? [String] ?? []
        }
        #expect(identifiers == ["mdta/com.apple.quicktime.cinematic-audio"])
        let described = try await metadataTracks[0].loadAssociatedTracks(ofType: .metadataReferent)
        #expect(described.map(\.trackID) == [spatialTrack.trackID])
    }

    @Test func test_groups_fallback_tracks_from_a_composition() async throws {
        let source = makeAsset(url: resourceURL(named: "test-spatial-audio.mov"))
        let composition = AVMutableComposition()
        let duration = try await source.load(.duration)
        var compositionTracks: [AVMutableCompositionTrack] = []
        for sourceTrack in try await source.load(.tracks) where sourceTrack.mediaType != .metadata {
            let track = try #require(composition.addMutableTrack(
                withMediaType: sourceTrack.mediaType,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ))
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceTrack, at: .zero)
            track.isEnabled = try await sourceTrack.load(.isEnabled)
            compositionTracks.append(track)
        }
        // Video, then the AAC track, then the spatial one.
        compositionTracks[2].addTrackAssociation(to: compositionTracks[1], type: .audioFallback)
        let destinationURL = makeTemporaryURL()

        try await ExportSession().export(
            asset: composition,
            audioOutputSettings: nil,
            videoOutputSettings: videoSettings,
            to: destinationURL.url,
            as: .mp4
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        let audioTracks = try await exportedAsset.loadTracks(withMediaType: .audio)
        try #require(audioTracks.count == 2)
        let groups = try await exportedAsset.load(.trackGroups).map { Set($0.trackIDs.map(\.int32Value)) }
        #expect(groups == [Set(audioTracks.map(\.trackID))])
        let fallbacks = try await audioTracks[1].loadAssociatedTracks(ofType: .audioFallback)
        #expect(fallbacks.map(\.trackID) == [audioTracks[0].trackID])
    }

    @Test func test_copies_surround_audio_as_it_is() async throws {
        let sourceURL = resourceURL(named: "test-5.1-audio.mp4")
        let destinationURL = makeTemporaryURL()

        try await ExportSession().export(
            asset: makeAsset(url: sourceURL),
            audioOutputSettings: nil,
            videoOutputSettings: VideoOutputSettings
                .codec(.h264, size: CGSize(width: 64, height: 64)).settingsDictionary,
            to: destinationURL.url,
            as: .mp4
        )

        let source = try await AudioTrackSummary.all(in: sourceURL)
        let exported = try await AudioTrackSummary.all(in: destinationURL.url)
        #expect(exported.map(\.subType) == [kAudioFormatMPEG4AAC])
        #expect(exported.map(\.channels) == [6])
        #expect(exported.map(\.packetBytes) == source.map(\.packetBytes))
    }

    @Test func test_copies_linear_pcm_into_an_mp4() async throws {
        let pcm = try await LinearPCMVideo.make(from: resourceURL(named: "test-720p-h264-24fps.mov"))
        let destinationURL = makeTemporaryURL()

        try await ExportSession().export(
            asset: makeAsset(url: pcm.url),
            audioOutputSettings: nil,
            videoOutputSettings: VideoOutputSettings
                .codec(.h264, size: CGSize(width: 64, height: 64)).settingsDictionary,
            to: destinationURL.url,
            as: .mp4
        )

        let source = try await AudioTrackSummary.all(in: pcm.url)
        let exported = try await AudioTrackSummary.all(in: destinationURL.url)
        #expect(exported.map(\.subType) == [kAudioFormatLinearPCM])
        #expect(exported.map(\.channels) == source.map(\.channels))
        #expect(exported.map(\.sampleRate) == source.map(\.sampleRate))
        #expect(exported.map(\.packetBytes) == source.map(\.packetBytes))
    }

    @Test func test_copies_audio_within_the_time_range() async throws {
        let sourceURL = resourceURL(named: "test-spatial-audio.mov")
        let destinationURL = makeTemporaryURL()
        let timeRange = CMTimeRange(start: .seconds(0.5), duration: .seconds(1))

        try await ExportSession().export(
            asset: makeAsset(url: sourceURL),
            timeRange: timeRange,
            audioOutputSettings: nil,
            videoOutputSettings: videoSettings,
            to: destinationURL.url,
            as: .mp4
        )

        let audioTracks = try await AVURLAsset(url: destinationURL.url).loadTracks(withMediaType: .audio)
        try #require(audioTracks.count == 2)
        for track in audioTracks {
            let duration = try await track.load(.timeRange).duration.seconds
            #expect(abs(duration - 1) < 0.05, "audio track \(track.trackID) lasts \(duration) s")
        }
    }

    @Test func test_copying_works_with_no_audio() async throws {
        let sourceURL = resourceURL(named: "test-no-audio.mp4")
        let destinationURL = makeTemporaryURL()

        try await ExportSession().export(
            asset: makeAsset(url: sourceURL),
            audioOutputSettings: nil,
            videoOutputSettings: VideoOutputSettings
                .codec(.h264, size: CGSize(width: 64, height: 64)).settingsDictionary,
            to: destinationURL.url,
            as: .mp4
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        #expect(try await exportedAsset.loadTracks(withMediaType: .audio).isEmpty)
        #expect(try await exportedAsset.loadTracks(withMediaType: .video).count == 1)
    }

    @Test func test_copying_throws_with_an_audio_mix() async throws {
        let sourceURL = resourceURL(named: "test-spatial-audio.mov")
        let destinationURL = makeTemporaryURL()

        await #expect(throws: ExportSession.Error.setupFailure(.audioSettingsInvalid)) {
            let asset = self.makeAsset(url: sourceURL)
            let audioTrack = try #require(await asset.loadTracks(withMediaType: .audio).first)
            let mix = AVMutableAudioMix()
            mix.inputParameters = [AVMutableAudioMixInputParameters(track: audioTrack)]
            try await ExportSession().export(
                asset: asset,
                audioOutputSettings: nil,
                mix: mix,
                videoOutputSettings: self.videoSettings,
                to: destinationURL.url,
                as: .mp4
            )
        }
    }
}

/// What a file's audio track holds, read without decoding it.
private struct AudioTrackSummary: Equatable {
    let subType: AudioFormatID
    let channels: UInt32
    let sampleRate: Float64
    let isEnabled: Bool
    let packetCount: Int
    let packetBytes: Int

    static func all(in url: URL) async throws -> [AudioTrackSummary] {
        let asset = AVURLAsset(url: url)
        var summaries: [AudioTrackSummary] = []
        for track in try await asset.loadTracks(withMediaType: .audio) {
            let (formats, isEnabled) = try await track.load(.formatDescriptions, .isEnabled)
            let format = try #require(formats.first)
            let description = try #require(format.audioStreamBasicDescription)
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            reader.add(output)
            reader.startReading()
            var packetCount = 0
            var packetBytes = 0
            while let sampleBuffer = output.copyNextSampleBuffer() {
                packetCount += CMSampleBufferGetNumSamples(sampleBuffer)
                packetBytes += CMSampleBufferGetTotalSampleSize(sampleBuffer)
            }
            summaries.append(AudioTrackSummary(
                subType: format.mediaSubType.rawValue,
                channels: description.mChannelsPerFrame,
                sampleRate: description.mSampleRate,
                isEnabled: isEnabled,
                packetCount: packetCount,
                packetBytes: packetBytes
            ))
        }
        return summaries
    }
}

/// A copy of a video with its audio decoded to 16-bit linear PCM, written as a QuickTime movie.
private struct LinearPCMVideo {
    let file: AutoDestructingURL

    var url: URL { file.url }

    static func make(from sourceURL: URL) async throws -> LinearPCMVideo {
        let url = URL.temporaryDirectory.appending(component: "test-lpcm-\(UUID().uuidString).mov")
        let file = AutoDestructingURL(url: url)
        let asset = AVURLAsset(url: sourceURL)
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)

        let videoTrack = try #require(await asset.loadTracks(withMediaType: .video).first)
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        reader.add(videoOutput)
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: nil,
            sourceFormatHint: try await videoTrack.load(.formatDescriptions).first
        )
        writer.add(videoInput)

        let audioTrack = try #require(await asset.loadTracks(withMediaType: .audio).first)
        let pcmSettings: [String: any Sendable] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: pcmSettings)
        reader.add(audioOutput)
        let audioDescription = try #require(await audioTrack.load(.formatDescriptions).first?.audioStreamBasicDescription)
        var audioSettings = pcmSettings
        audioSettings[AVSampleRateKey] = audioDescription.mSampleRate
        audioSettings[AVNumberOfChannelsKey] = audioDescription.mChannelsPerFrame
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        writer.add(audioInput)

        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        // The writer wants the tracks interleaved, so neither is written out in one go.
        var pending = [(videoOutput, videoInput), (audioOutput, audioInput)]
        while !pending.isEmpty {
            var wroteAny = false
            pending = pending.filter { output, input in
                guard input.isReadyForMoreMediaData else { return true }
                wroteAny = true
                guard let sampleBuffer = output.copyNextSampleBuffer() else {
                    input.markAsFinished()
                    return false
                }
                input.append(sampleBuffer)
                return true
            }
            if !wroteAny {
                try await Task.sleep(for: .milliseconds(5))
            }
        }
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? TestVideoError.writeFailed }

        return LinearPCMVideo(file: file)
    }
}
