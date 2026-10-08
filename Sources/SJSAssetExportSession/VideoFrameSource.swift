//
//  VideoFrameSource.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2026-10-07.
//

import AVFoundation
import VideoToolbox

/// Hands the writer the composition's frames, drawn into by the artist, at the composition's
/// frame rate when it times its frames with `frameDuration`.
///
/// The built-in compositor only emits the source's own frames, even when the composition asks
/// for a steady rate, so a 2 fps screen recording exported at 30 fps would come out at 2 fps.
/// Instead each source frame fills every output frame from where the last one left off until
/// the next source frame starts, so sparse frames repeat and extra ones drop, and the last
/// source frame fills to the end of the time range.
final class VideoFrameSource {
    private let output: AVAssetReaderVideoCompositionOutput
    private let drawFrame: FrameArtist?
    private let colour: FrameColour
    private var timeline: FrameTimeline?
    private let copier = PixelBufferCopier()

    /// The source frame being shown, the one after it, and the output times left to show it at.
    private var current: CMSampleBuffer?
    private var upcoming: CMSampleBuffer?
    private var pendingTimes: [CMTime] = []
    private var isRepeated = false

    init(
        output: AVAssetReaderVideoCompositionOutput,
        videoComposition: AVVideoComposition,
        timeRange: CMTimeRange,
        drawFrame: sending FrameArtist?
    ) {
        self.output = output
        self.drawFrame = drawFrame
        colour = FrameColour(of: videoComposition)
        let frameDuration = videoComposition.frameDuration
        if videoComposition.sourceTrackIDForFrameTiming == kCMPersistentTrackID_Invalid,
           frameDuration.isNumeric, frameDuration > .zero
        {
            timeline = FrameTimeline(frameDuration: frameDuration, timeRange: timeRange)
        }
    }

    /// The next frame for the writer, or nil when there are no more.
    func next() throws -> CMSampleBuffer? {
        guard timeline != nil else {
            guard let sample = output.copyNextSampleBuffer() else { return nil }

            try draw(into: sample, at: CMSampleBufferGetPresentationTimeStamp(sample))
            return sample
        }

        while pendingTimes.isEmpty {
            guard let sample = upcoming ?? output.copyNextSampleBuffer() else { return nil }

            let next = output.copyNextSampleBuffer()
            let times = timeline?.times(before: next.map(CMSampleBufferGetPresentationTimeStamp)) ?? []
            current = sample
            upcoming = next
            pendingTimes = times
            isRepeated = times.count > 1
            if next == nil, times.isEmpty {
                return nil
            }
        }
        guard let current, let frameDuration = timeline?.frameDuration else { return nil }

        let time = pendingTimes.removeFirst()
        let timing = CMSampleTimingInfo(duration: frameDuration, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        guard isRepeated, drawFrame != nil, let source = CMSampleBufferGetImageBuffer(current) else {
            // Shown once, or with nothing to draw: the reader's own frame, retimed.
            try draw(into: current, at: time)
            return try CMSampleBuffer(copying: current, withNewTiming: [timing])
        }

        // Shown more than once, so each showing gets a copy to draw into at its own time.
        let copy = try copier.copy(source)
        try drawFrame?(VideoFrame(pixelBuffer: copy, presentationTime: time, colour: colour))
        return try CMSampleBuffer(
            imageBuffer: copy,
            formatDescription: CMVideoFormatDescription(imageBuffer: copy),
            sampleTiming: timing
        )
    }

    private func draw(into sample: CMSampleBuffer, at time: CMTime) throws {
        guard let drawFrame, let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { return }

        try drawFrame(VideoFrame(pixelBuffer: pixelBuffer, presentationTime: time, colour: colour))
    }
}

/// The output frame times at a steady rate across a time range.
struct FrameTimeline {
    let frameDuration: CMTime
    let timeRange: CMTimeRange
    private var nextIndex: Int32 = 0

    init(frameDuration: CMTime, timeRange: CMTimeRange) {
        self.frameDuration = frameDuration
        self.timeRange = timeRange
    }

    /// The output times not yet handed out that come before `limit`, the next source frame's
    /// time, or before the end of the time range when there are no more source frames.
    mutating func times(before limit: CMTime?) -> [CMTime] {
        let end = limit.map { min($0, timeRange.end) } ?? timeRange.end
        var times: [CMTime] = []
        while true {
            let time = timeRange.start + CMTimeMultiply(frameDuration, multiplier: nextIndex)
            guard time < end else { break }

            times.append(time)
            nextIndex += 1
        }
        return times
    }
}

/// Copies frames into pooled buffers with the same format, attachments and Metal compatibility
/// as the reader's frames.
final class PixelBufferCopier {
    private var session: VTPixelTransferSession?
    private var pool: CVPixelBufferPool?

    func copy(_ source: CVPixelBuffer) throws -> CVPixelBuffer {
        let pool = try pool ?? makePool(like: source)
        self.pool = pool
        var copy: CVPixelBuffer?
        try check(CVPixelBufferPoolCreatePixelBuffer(nil, pool, &copy))
        guard let copy else { throw ExportSession.Error.writeFailure(nil) }

        let session = try session ?? makeSession()
        self.session = session
        try check(VTPixelTransferSessionTransferImage(session, from: source, to: copy))
        CVBufferPropagateAttachments(source, copy)
        return copy
    }

    private func makePool(like source: CVPixelBuffer) throws -> CVPixelBufferPool {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: CVPixelBufferGetPixelFormatType(source),
            kCVPixelBufferWidthKey as String: CVPixelBufferGetWidth(source),
            kCVPixelBufferHeightKey as String: CVPixelBufferGetHeight(source),
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
        var pool: CVPixelBufferPool?
        try check(CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool))
        guard let pool else { throw ExportSession.Error.writeFailure(nil) }

        return pool
    }

    private func makeSession() throws -> VTPixelTransferSession {
        var session: VTPixelTransferSession?
        try check(VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &session))
        guard let session else { throw ExportSession.Error.writeFailure(nil) }

        return session
    }

    private func check(_ status: OSStatus) throws {
        guard status == noErr else {
            throw ExportSession.Error.writeFailure(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }

    deinit {
        if let session {
            VTPixelTransferSessionInvalidate(session)
        }
    }
}
