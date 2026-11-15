import AVFoundation

/// How long a video track lasts and how many frames it has, to check that an export did all of
/// the work it was timed for.
public struct VideoSummary: Equatable, Sendable, CustomStringConvertible {
    public struct Mismatch: Swift.Error, Equatable, CustomStringConvertible {
        public let expected: VideoSummary
        public let actual: VideoSummary

        public init(expected: VideoSummary, actual: VideoSummary) {
            self.expected = expected
            self.actual = actual
        }

        public var description: String {
            "Expected an export of about \(expected) but got \(actual)"
        }
    }

    public enum Error: Swift.Error {
        case noVideoTrack(URL)
        case unreadable(URL, (any Swift.Error)?)
    }

    /// In seconds.
    public let duration: Double
    public let frameCount: Int

    public init(duration: Double, frameCount: Int) {
        self.duration = duration
        self.frameCount = frameCount
    }

    public var description: String {
        "\(frameCount) frames over \(duration.formatted(.number.precision(.fractionLength(2))))s"
    }

    public static func of(_ url: URL) async throws -> VideoSummary {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw Error.noVideoTrack(url)
        }
        let timeRange = try await track.load(.timeRange)
        let reader = try AVAssetReader(asset: asset)
        // Compressed samples are enough to count frames, and reading them skips decoding.
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        guard reader.startReading() else { throw Error.unreadable(url, reader.error) }
        var frameCount = 0
        while let sample = output.copyNextSampleBuffer() {
            frameCount += CMSampleBufferGetNumSamples(sample)
        }
        guard reader.status == .completed else { throw Error.unreadable(url, reader.error) }
        return VideoSummary(duration: timeRange.duration.seconds, frameCount: frameCount)
    }

    /// What an export of this video should come out as at `fps`, or unchanged when `fps` is nil.
    public func converted(toFPS fps: Int?) -> VideoSummary {
        guard let fps else { return self }
        return VideoSummary(duration: duration, frameCount: Int((duration * Double(fps)).rounded()))
    }

    /// Throws when this has noticeably fewer or more frames, or a different duration, than
    /// `expected`.
    public func verify(matches expected: VideoSummary, tolerance: Double = 0.02) throws {
        func isClose(_ a: Double, _ b: Double) -> Bool {
            abs(a - b) <= b * tolerance
        }
        guard isClose(duration, expected.duration),
              isClose(Double(frameCount), Double(expected.frameCount))
        else {
            throw Mismatch(expected: expected, actual: self)
        }
    }
}
