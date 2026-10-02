//
//  AudioMixTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2026-09-22.
//

import AVFoundation
import SJSAssetExportSession
import Testing

final class AudioMixTests: BaseTests {
    /// Reproduces Forgejo issue #1: a 44.1 kHz clip track mixed with a 48 kHz music track, where
    /// the clips switch between mono and stereo and most of them are muted with 0 → 0 volume
    /// ramps. With the mix output format left to AVFoundation the clip track can go silent from
    /// some point onward while the music keeps playing and the export reports success.
    ///
    /// Every third clip is audible stereo and the other two are muted mono. It takes around 120
    /// clips of 2 seconds to reproduce reliably; far fewer clips, or shorter ones, don't, and
    /// neither does a 44.1 kHz music track.
    @Test func test_audio_mix_keeps_clip_audio_through_a_long_export() async throws {
        let clipCount = 120
        let clipDuration = CMTime(seconds: 2, preferredTimescale: 600)
        let duration = CMTimeMultiply(clipDuration, multiplier: Int32(clipCount))

        let workDirectory = URL.temporaryDirectory.appending(component: "AudioMixTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDirectory) }
        let monoURL = workDirectory.appending(component: "mono.m4a")
        let stereoURL = workDirectory.appending(component: "stereo.m4a")
        let musicURL = workDirectory.appending(component: "music.m4a")
        try writeTone(to: monoURL, seconds: clipDuration.seconds + 0.1, sampleRate: 44_100, channels: 1, frequency: 1_000)
        try writeTone(to: stereoURL, seconds: clipDuration.seconds + 0.1, sampleRate: 44_100, channels: 2, frequency: 1_000)
        try writeTone(to: musicURL, seconds: duration.seconds + 1, sampleRate: 48_000, channels: 2, frequency: 220)

        let destinationURL = makeTemporaryURL()
        try await ExportSession().export(
            asset: makeComposition(clipCount: clipCount, clipDuration: clipDuration, monoURL: monoURL, stereoURL: stereoURL, musicURL: musicURL),
            mix: makeAudioMix(clipCount: clipCount, clipDuration: clipDuration),
            video: .codec(.h264, width: 160, height: 90).fps(1),
            to: destinationURL.url,
            as: .mp4
        )

        let samples = try await readMonoSamples(url: destinationURL.url)
        let silentClips = stride(from: 2, to: clipCount, by: 3).filter { index in
            let start = Double(index) * clipDuration.seconds
            let window = (start + 0.2) ... (start + clipDuration.seconds - 0.2)
            return toneAmplitude(samples, in: window, frequency: 1_000) < 0.05
        }
        #expect(silentClips.isEmpty, "Clip audio went silent from clip \(silentClips.first ?? -1) onward")
    }

    private static let clipTrackID: CMPersistentTrackID = 1

    private func makeComposition(
        clipCount: Int,
        clipDuration: CMTime,
        monoURL: URL,
        stereoURL: URL,
        musicURL: URL
    ) async throws -> sending AVMutableComposition {
        let duration = CMTimeMultiply(clipDuration, multiplier: Int32(clipCount))
        let composition = AVMutableComposition()
        let clipTrack = try #require(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Self.clipTrackID))
        let monoAsset = makeAsset(url: monoURL)
        let mono = try #require(await monoAsset.loadTracks(withMediaType: .audio).first)
        let stereoAsset = makeAsset(url: stereoURL)
        let stereo = try #require(await stereoAsset.loadTracks(withMediaType: .audio).first)
        for index in 0 ..< clipCount {
            let source = index % 3 == 2 ? stereo : mono
            let start = CMTimeMultiply(clipDuration, multiplier: Int32(index))
            try clipTrack.insertTimeRange(CMTimeRange(start: .zero, duration: clipDuration), of: source, at: start)
        }

        let musicTrack = try #require(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
        let musicAsset = makeAsset(url: musicURL)
        let music = try #require(await musicAsset.loadTracks(withMediaType: .audio).first)
        try musicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: music, at: .zero)

        // ExportSession requires a video track but a short one is enough.
        let videoTrack = try #require(composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid))
        let videoAsset = makeAsset(url: resourceURL(named: "test-720p-h264-24fps.mov"))
        let video = try #require(await videoAsset.loadTracks(withMediaType: .video).first)
        let videoRange = try await video.load(.timeRange)
        try videoTrack.insertTimeRange(videoRange, of: video, at: .zero)

        return composition
    }

    /// Fades every clip in and out over 0.1 seconds. Audible clips fade to 0.5 and muted clips
    /// "fade" from 0 to 0.
    private func makeAudioMix(
        clipCount: Int,
        clipDuration: CMTime
    ) -> sending AVMutableAudioMix {
        let parameters = AVMutableAudioMixInputParameters()
        parameters.trackID = Self.clipTrackID
        let fade = CMTime(seconds: 0.1, preferredTimescale: 600)
        for index in 0 ..< clipCount {
            let volume: Float = index % 3 == 2 ? 0.5 : 0
            let start = CMTimeMultiply(clipDuration, multiplier: Int32(index))
            let end = start + clipDuration
            parameters.setVolumeRamp(fromStartVolume: 0, toEndVolume: volume, timeRange: CMTimeRange(start: start, duration: fade))
            parameters.setVolumeRamp(fromStartVolume: volume, toEndVolume: 0, timeRange: CMTimeRange(start: end - fade, duration: fade))
        }
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        return mix
    }

    // MARK: - Audio helpers

    private func writeTone(to url: URL, seconds: Double, sampleRate: Double, channels: Int, frequency: Double) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        // Whole-number frequencies complete a whole number of cycles every second, so one second
        // of samples can be written over and over.
        let frameCount = AVAudioFrameCount(sampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        for channel in 0 ..< channels {
            let data = buffer.floatChannelData![channel]
            for i in 0 ..< Int(frameCount) {
                data[i] = 0.5 * Float(sin(2 * .pi * frequency * Double(i) / sampleRate))
            }
        }
        for _ in 0 ..< Int(seconds.rounded(.up)) {
            try file.write(from: buffer)
        }
    }

    private func readMonoSamples(url: URL) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        let track = try #require(await asset.loadTracks(withMediaType: .audio).first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
        ])
        reader.add(output)
        reader.startReading()
        var samples: [Float] = []
        while let sampleBuffer = output.copyNextSampleBuffer(), let blockBuffer = sampleBuffer.dataBuffer {
            var chunk = [Float](repeating: 0, count: CMBlockBufferGetDataLength(blockBuffer) / MemoryLayout<Float>.size)
            _ = chunk.withUnsafeMutableBytes { bytes in
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: bytes.count, destination: bytes.baseAddress!)
            }
            samples += chunk
        }
        return samples
    }

    /// Amplitude of a single frequency within a window of 44.1 kHz mono samples.
    private func toneAmplitude(_ samples: [Float], in window: ClosedRange<Double>, frequency: Double) -> Double {
        let start = Int(window.lowerBound * 44_100)
        let end = min(Int(window.upperBound * 44_100), samples.count)
        guard end > start else { return 0 }
        var real = 0.0
        var imaginary = 0.0
        for i in start ..< end {
            let phase = 2 * .pi * frequency * Double(i) / 44_100
            real += Double(samples[i]) * cos(phase)
            imaginary += Double(samples[i]) * sin(phase)
        }
        return 2 * (real * real + imaginary * imaginary).squareRoot() / Double(end - start)
    }
}
