//
//  VarispeedMixTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2026-11-27.
//

import AVFoundation
@testable import SJSAssetExportSession
import Testing

final class VarispeedMixTests: BaseTests {
    /// Forgejo issue #20: Photos hands over a slo-mo video as a time-scaled composition and a mix
    /// that sets `.varispeed`. Reading a cut of a second or less from the slowed part with that
    /// mix never finishes.
    @Test func test_export_finishes_for_a_short_cut_of_slowed_audio_with_a_varispeed_mix() async throws {
        let destinationURL = makeTemporaryURL()
        let url = destinationURL.url
        let sourceURL = resourceURL(named: "test-720p-h264-24fps.mov")

        let finished = try await finishes(within: .seconds(60)) {
            let slowed = try await Self.slowedRange(sourceURL: sourceURL)
            let middle = CMTimeAdd(slowed.start, CMTimeMultiplyByFloat64(slowed.duration, multiplier: 0.5))
            try await ExportSession().export(
                asset: Self.makeSlowMotionComposition(sourceURL: sourceURL),
                timeRange: CMTimeRange(start: middle, duration: CMTime(value: 1, timescale: 1)),
                mix: Self.makeVarispeedMix(),
                video: .codec(.h264, width: 320, height: 180),
                to: url,
                as: .mp4
            )
        }

        #expect(finished, "The export didn't finish")
        guard finished else { return }
        let output = makeAsset(url: url)
        let duration = try await output.load(.duration)
        #expect(abs(duration.seconds - 1) < 0.1)
        #expect(try await output.loadTracks(withMediaType: .audio).count == 1)
    }

    @Test func test_a_mix_without_varispeed_is_used_as_it_is() {
        let parameters = AVMutableAudioMixInputParameters()
        parameters.trackID = 2
        parameters.audioTimePitchAlgorithm = .spectral
        parameters.setVolume(0.5, at: .zero)
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]

        #expect(mix.withoutVarispeed() === mix)
    }

    @Test func test_varispeed_is_cleared_and_everything_else_in_the_mix_is_kept() throws {
        let slowMotion = AVMutableAudioMixInputParameters()
        slowMotion.trackID = 2
        slowMotion.audioTimePitchAlgorithm = .varispeed
        let duck = CMTimeRange(start: CMTime(value: 385, timescale: 600), duration: CMTime(value: 60, timescale: 600))
        slowMotion.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0.15, timeRange: duck)
        let other = AVMutableAudioMixInputParameters()
        other.trackID = 3
        other.audioTimePitchAlgorithm = .timeDomain
        let mix = AVMutableAudioMix()
        mix.inputParameters = [slowMotion, other]

        let cleared = mix.withoutVarispeed()

        #expect(cleared.inputParameters.map(\.trackID) == [2, 3])
        #expect(cleared.inputParameters[0].audioTimePitchAlgorithm == nil)
        #expect(cleared.inputParameters[1].audioTimePitchAlgorithm == .timeDomain)
        var start: Float = 0
        var end: Float = 0
        var range = CMTimeRange.zero
        #expect(cleared.inputParameters[0].getVolumeRamp(for: duck.start, startVolume: &start, endVolume: &end, timeRange: &range))
        #expect(range == duck)
        #expect(start == 1)
        #expect(end == 0.15)
        // The caller's mix is left alone.
        #expect(mix.inputParameters[0].audioTimePitchAlgorithm == .varispeed)
    }

    // MARK: - Helpers

    /// Runs the operation in its own task and gives up on it after the deadline, so an export
    /// that never returns fails the test instead of hanging the suite.
    private func finishes(
        within deadline: Duration,
        _ operation: @escaping @Sendable () async throws -> Void
    ) async throws -> Bool {
        let (stream, continuation) = AsyncStream<Result<Bool, any Error>>.makeStream()
        let work = Task {
            do {
                try await operation()
                continuation.yield(.success(true))
            } catch {
                continuation.yield(.failure(error))
            }
        }
        let timer = Task {
            try await Task.sleep(for: deadline)
            continuation.yield(.success(false))
        }
        defer {
            work.cancel()
            timer.cancel()
        }
        for await result in stream {
            return try result.get()
        }
        return false
    }

    private static let audioTrackID: CMPersistentTrackID = 2

    /// Shaped like the slo-mo Photos returns: the middle half of the video plays at a quarter of
    /// its speed.
    private static func makeSlowMotionComposition(sourceURL: URL) async throws -> sending AVMutableComposition {
        let source = AVURLAsset(url: sourceURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let sourceVideo = try #require(await source.loadTracks(withMediaType: .video).first)
        let sourceAudio = try #require(await source.loadTracks(withMediaType: .audio).first)
        let range = try await sourceVideo.load(.timeRange)

        let composition = AVMutableComposition()
        let video = try #require(composition.addMutableTrack(withMediaType: .video, preferredTrackID: 1))
        let audio = try #require(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: audioTrackID))
        try video.insertTimeRange(range, of: sourceVideo, at: .zero)
        try audio.insertTimeRange(range, of: sourceAudio, at: .zero)

        let slowed = try await slowedRange(sourceURL: sourceURL)
        composition.scaleTimeRange(
            CMTimeRange(start: slowed.start, duration: CMTimeMultiplyByFloat64(slowed.duration, multiplier: 0.25)),
            toDuration: slowed.duration
        )
        return composition
    }

    /// Where the slowed part sits in the composition, once it's been stretched.
    private static func slowedRange(sourceURL: URL) async throws -> CMTimeRange {
        let duration = try await AVURLAsset(url: sourceURL).load(.duration)
        return CMTimeRange(
            start: CMTimeMultiplyByFloat64(duration, multiplier: 0.25),
            duration: CMTimeMultiplyByFloat64(duration, multiplier: 2)
        )
    }

    private static func makeVarispeedMix() -> sending AVMutableAudioMix {
        let parameters = AVMutableAudioMixInputParameters()
        parameters.trackID = audioTrackID
        parameters.audioTimePitchAlgorithm = .varispeed
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        return mix
    }
}
