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

    // MARK: - Reading exports

    /// Runs a read that blocks its thread, such as a `copyNextSampleBuffer` loop, on a dispatch
    /// queue. On a 10-core Mac, tests blocking every thread in Swift's cooperative pool this way
    /// stalled exports running in other tests for good.
    func readBlocking<T: Sendable>(_ read: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try read() })
            }
        }
    }

    func countFrames(of url: URL) async throws -> Int {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let reader = try AVAssetReader(asset: asset)
        // Handed off to the read below and not touched here again.
        nonisolated(unsafe) let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        reader.startReading()
        return try await readBlocking {
            var count = 0
            while let sample = output.copyNextSampleBuffer() {
                count += CMSampleBufferGetNumSamples(sample)
            }
            return count
        }
    }
}
