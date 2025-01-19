//
//  BaseTests.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2025-01-19.
//

import AVFoundation
import Foundation
import Testing

class BaseTests {
    func resourceURL(named name: String) -> URL {
        Bundle.module.resourceURL!.appending(component: name)
    }

    func makeAsset(url: URL) -> sending AVAsset {
        AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true,
        ])
    }

    func makeTemporaryURL(function: String = #function) -> AutoDestructingURL {
        let timestamp = Int(Date.now.timeIntervalSince1970)
        let f = function.replacing(/[\(\)]/, with: { _ in "" })
        let filename = "\(Self.self)_\(f)_\(timestamp).mp4"
        let url = URL.temporaryDirectory.appending(component: filename)
        return AutoDestructingURL(url: url)
    }

    func makeVideoComposition(
        assetURL: URL,
        size: CGSize? = nil,
        fps: Int? = nil
    ) async throws -> sending AVMutableVideoComposition {
        let asset = makeAsset(url: assetURL)
        let videoComposition = try await AVMutableVideoComposition.videoComposition(
            withPropertiesOf: asset
        )
        if let size {
            videoComposition.renderSize = size
        }
        if let fps {
            let seconds = 1.0 / TimeInterval(fps)
            videoComposition.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
            videoComposition.frameDuration = CMTime(seconds: seconds, preferredTimescale: 600)
        }
        return videoComposition
    }
}
