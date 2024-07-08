//
//  AVAsset+sending.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-07.
//

internal import AVFoundation

extension AVAsset {
    func sendTracks(withMediaType mediaType: AVMediaType) async throws -> sending [AVAssetTrack] {
        try await loadTracks(withMediaType: mediaType)
    }
}
