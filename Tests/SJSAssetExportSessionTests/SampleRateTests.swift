//
//  SampleRateTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2026-11-15.
//

import AVFoundation
@testable import SJSAssetExportSession
import Testing

struct SampleRateTests {
    @Test func test_uses_the_rate_the_source_tracks_share() {
        #expect(SampleWriter.sampleRate(encoding: kAudioFormatMPEG4AAC, from: [48_000, 48_000]) == 48_000)
    }

    @Test func test_uses_44_1_khz_when_source_rates_differ() {
        #expect(SampleWriter.sampleRate(encoding: kAudioFormatMPEG4AAC, from: [44_100, 48_000]) == 44_100)
        #expect(SampleWriter.sampleRate(encoding: kAudioFormatMPEG4AAC, from: [48_000, 96_000]) == 44_100)
    }

    @Test func test_caps_at_the_highest_rate_the_format_can_encode() {
        #expect(SampleWriter.sampleRate(encoding: kAudioFormatMPEG4AAC, from: [96_000]) == 48_000)
    }

    @Test func test_rounds_an_unencodable_rate_down_to_one_the_format_can_encode() {
        #expect(SampleWriter.sampleRate(encoding: kAudioFormatMPEG4AAC, from: [37_800]) == 32_000)
    }

    @Test func test_has_no_rate_without_a_source_rate() {
        #expect(SampleWriter.sampleRate(encoding: kAudioFormatMPEG4AAC, from: []) == nil)
    }
}
