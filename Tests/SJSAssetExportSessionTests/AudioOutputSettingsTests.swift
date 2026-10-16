//
//  AudioOutputSettingsTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2026-10-16.
//

import AVFoundation
import Foundation
import SJSAssetExportSession
import Testing

struct AudioOutputSettingsTests {
    private func layoutTag(in settings: [String: any Sendable]) -> AudioChannelLayoutTag? {
        guard let data = settings[AVChannelLayoutKey] as? Data else { return nil }
        return data.withUnsafeBytes { $0.load(as: AudioChannelLayout.self).mChannelLayoutTag }
    }

    @Test func test_stereo_and_mono_leave_the_layout_out() {
        #expect(AudioOutputSettings.default.settingsDictionary[AVChannelLayoutKey] == nil)
        #expect(AudioOutputSettings.format(.aac).channels(1).settingsDictionary[AVChannelLayoutKey] == nil)
    }

    @Test(arguments: [
        (3, kAudioChannelLayoutTag_AAC_3_0),
        (4, kAudioChannelLayoutTag_AAC_Quadraphonic),
        (5, kAudioChannelLayoutTag_AAC_5_0),
        (6, kAudioChannelLayoutTag_AAC_5_1),
        (7, kAudioChannelLayoutTag_AAC_6_1),
        (8, kAudioChannelLayoutTag_AAC_7_1),
    ])
    func test_more_than_two_channels_get_the_aac_layout_for_that_count(
        channels: Int,
        expected: AudioChannelLayoutTag
    ) {
        let settings = AudioOutputSettings.format(.aac).channels(channels)

        #expect(layoutTag(in: settings.settingsDictionary) == expected)
    }
}
