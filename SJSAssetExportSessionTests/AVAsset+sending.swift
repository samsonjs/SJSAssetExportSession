//
//  AVAsset+sending.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2024-07-07.
//

import AVFoundation

extension AVAsset {
    func sendTracks(withMediaType mediaType: AVMediaType) async throws -> sending [AVAssetTrack] {
        try await loadTracks(withMediaType: mediaType)
    }
}
