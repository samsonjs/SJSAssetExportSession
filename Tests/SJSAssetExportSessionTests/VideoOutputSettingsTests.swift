//
//  VideoOutputSettingsTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2026-11-07.
//

import Foundation
import SJSAssetExportSession
import Testing

struct VideoOutputSettingsTests {
    @Test func test_scale_mode_defaults_to_fit() {
        #expect(VideoOutputSettings.codec(.h264, width: 1280, height: 720).scaleMode == .fit)
    }

    @Test func test_scale_mode_survives_other_settings() {
        let settings = VideoOutputSettings.codec(.hevc, width: 1080, height: 1080)
            .scaleMode(.fill)
            .fps(30)
            .bitrate(2_000_000)
            .color(.hdr)

        #expect(settings.scaleMode == .fill)
    }

    @Test func test_decoding_settings_encoded_without_a_scale_mode_gives_fit() throws {
        let encoded = try JSONEncoder().encode(VideoOutputSettings.codec(.h264, width: 1280, height: 720).scaleMode(.stretch))
        var object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["scaleMode"] = nil
        let legacy = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(VideoOutputSettings.self, from: legacy)

        #expect(decoded == .codec(.h264, width: 1280, height: 720))
    }
}
