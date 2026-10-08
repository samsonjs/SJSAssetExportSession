//
//  DrawFrameTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2026-10-07.
//

import AVFoundation
import Metal
import SJSAssetExportSession
import Testing

final class DrawFrameTests: BaseTests {
    struct Bail: Error, Equatable {}

    @Test func test_draw_frame_is_called_once_per_frame_in_order() async throws {
        let video = try await TestVideo.make(fps: 30, frameCount: 10)
        let destinationURL = makeTemporaryURL()
        let times = SendableWrapper<[CMTime]>([])

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            video: .codec(.h264, size: TestVideo.size),
            drawFrame: { frame in times.value.append(frame.presentationTime) },
            to: destinationURL.url,
            as: .mp4
        )

        #expect(times.value.count == 10)
        #expect(times.value == times.value.sorted())
        #expect(try await countFrames(of: destinationURL.url) == 10)
    }

    @Test func test_draw_frame_draws_into_the_exported_frames() async throws {
        let video = try await TestVideo.make()
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            video: .codec(.h264, size: TestVideo.size),
            drawFrame: { frame in
                fillWhite(CGRect(x: 0, y: 0, width: 40, height: 40), in: frame.pixelBuffer)
            },
            to: destinationURL.url,
            as: .mp4
        )

        let exported = try await DecodedFrame.at(CMTime(value: 5, timescale: 30), in: destinationURL.url)
        #expect(exported.colour(at: CGPoint(x: 20, y: 20)) == .white)
        #expect(exported.colour(at: CGPoint(x: 200, y: 100)) == .blue)
    }

    /// The artist draws into the frames the composition hands over, which aren't copied first.
    /// If one were a buffer the decoder still predicts later frames from, what was drawn
    /// into it would turn up again in later frames.
    @Test func test_drawing_into_frames_leaves_no_trail() async throws {
        let video = try await TestVideo.make(fps: 30, frameCount: 15)
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            video: .codec(.h264, size: TestVideo.size),
            drawFrame: { frame in
                // A square sliding right 100 points a second.
                let x = 100 * frame.presentationTime.seconds
                fillWhite(CGRect(x: x, y: 160, width: 20, height: 20), in: frame.pixelBuffer)
            },
            to: destinationURL.url,
            as: .mp4
        )

        // At 0.4 s the square spans x = 40 to 60, and where it started is blue again.
        let later = try await DecodedFrame.at(CMTime(value: 12, timescale: 30), in: destinationURL.url)
        #expect(later.colour(at: CGPoint(x: 10, y: 170)) == .blue)
        #expect(later.colour(at: CGPoint(x: 50, y: 170)) == .white)
    }

    @Test func test_draw_frame_errors_fail_the_export() async throws {
        let video = try await TestVideo.make()
        let destinationURL = makeTemporaryURL()
        let calls = SendableWrapper(0)

        let subject = ExportSession()
        await #expect(throws: Bail()) {
            try await subject.export(
                asset: self.makeAsset(url: video.url.url),
                video: .codec(.h264, size: TestVideo.size),
                drawFrame: { _ in
                    calls.value += 1
                    if calls.value == 3 { throw Bail() }
                },
                to: destinationURL.url,
                as: .mp4
            )
        }
        #expect(calls.value == 3)
    }

    @Test func test_draw_frame_gets_8_bit_frames_and_709_colour_for_sdr() async throws {
        let sourceURL = resourceURL(named: "test-4k-hdr-hevc-30fps.mov")
        let frames = SendableWrapper<[FrameFacts]>([])

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 3, timescale: 30)),
            video: .codec(.hevc, width: 1280, height: 720).color(.sdr),
            drawFrame: { frame in frames.value.append(FrameFacts(frame)) },
            to: makeTemporaryURL().url,
            as: .mp4
        )

        let facts = try #require(frames.value.first)
        #expect(facts.pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        #expect(facts.colorPrimaries == AVVideoColorPrimaries_ITU_R_709_2)
        #expect(facts.transferFunction == AVVideoTransferFunction_ITU_R_709_2)
        #expect(facts.yCbCrMatrix == AVVideoYCbCrMatrix_ITU_R_709_2)
    }

    @Test func test_draw_frame_gets_10_bit_frames_and_hlg_colour_for_hdr() async throws {
        let sourceURL = resourceURL(named: "test-4k-hdr-hevc-30fps.mov")
        let frames = SendableWrapper<[FrameFacts]>([])

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 3, timescale: 30)),
            video: .codec(.hevc, width: 1280, height: 720).color(.hdr),
            drawFrame: { frame in frames.value.append(FrameFacts(frame)) },
            to: makeTemporaryURL().url,
            as: .mp4
        )

        let facts = try #require(frames.value.first)
        #expect(facts.pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        #expect(facts.colorPrimaries == AVVideoColorPrimaries_ITU_R_2020)
        #expect(facts.transferFunction == AVVideoTransferFunction_ITU_R_2100_HLG)
        #expect(facts.yCbCrMatrix == AVVideoYCbCrMatrix_ITU_R_2020)
    }

    /// A composition that scales its source with a layer instruction, as an editing app builds,
    /// rather than the one the convenience method builds.
    @Test func test_draw_frame_gets_10_bit_frames_from_a_scaling_hdr_composition() async throws {
        let (composition, videoComposition) = try await makeScalingComposition(
            of: resourceURL(named: "test-4k-hdr-hevc-30fps.mov"),
            to: CGSize(width: 1280, height: 720),
            hdr: true
        )
        let frames = SendableWrapper<[FrameFacts]>([])

        let subject = ExportSession()
        try await subject.export(
            asset: composition,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 3, timescale: 30)),
            audioOutputSettings: AudioOutputSettings.default.settingsDictionary,
            videoOutputSettings: VideoOutputSettings.codec(.hevc, width: 1280, height: 720)
                .color(.hdr)
                .settingsDictionary,
            composition: videoComposition,
            drawFrame: { frame in frames.value.append(FrameFacts(frame)) },
            to: makeTemporaryURL().url,
            as: .mp4
        )

        let facts = try #require(frames.value.first)
        #expect(facts.pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        #expect(facts.isMetalCompatible)
    }

    @Test func test_draw_frame_gets_frames_metal_can_draw_into() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        let cache = try #require(textureCache)
        let video = try await TestVideo.make(frameCount: 3)
        let results = SendableWrapper<[CVReturn]>([])

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            video: .codec(.h264, size: TestVideo.size),
            drawFrame: { frame in
                var texture: CVMetalTexture?
                let result = CVMetalTextureCacheCreateTextureFromImage(
                    nil,
                    cache,
                    frame.pixelBuffer,
                    nil,
                    .r8Unorm,
                    CVPixelBufferGetWidthOfPlane(frame.pixelBuffer, 0),
                    CVPixelBufferGetHeightOfPlane(frame.pixelBuffer, 0),
                    0,
                    &texture
                )
                results.value.append(result)
            },
            to: makeTemporaryURL().url,
            as: .mp4
        )

        #expect(results.value == [kCVReturnSuccess, kCVReturnSuccess, kCVReturnSuccess])
    }

    @Test func test_draw_frame_with_surround_audio_exports_stereo() async throws {
        let sourceURL = resourceURL(named: "test-5.1-audio.mp4")
        let destinationURL = makeTemporaryURL()

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: sourceURL),
            video: .codec(.h264, size: CGSize(width: 64, height: 64)),
            drawFrame: { frame in
                fillWhite(CGRect(x: 0, y: 0, width: 8, height: 8), in: frame.pixelBuffer)
            },
            to: destinationURL.url,
            as: .mp4
        )

        let exportedAsset = AVURLAsset(url: destinationURL.url)
        let audioTrack = try #require(await exportedAsset.loadTracks(withMediaType: .audio).first)
        let audioFormat = try #require(await audioTrack.load(.formatDescriptions).first)
        #expect(audioFormat.audioStreamBasicDescription?.mChannelsPerFrame == 2)
    }

    @Test func test_draw_frame_with_dictionary_settings() async throws {
        let video = try await TestVideo.make()
        let destinationURL = makeTemporaryURL()
        let calls = SendableWrapper(0)

        let subject = ExportSession()
        try await subject.export(
            asset: makeAsset(url: video.url.url),
            audioOutputSettings: [:],
            videoOutputSettings: VideoOutputSettings.codec(.h264, size: TestVideo.size).settingsDictionary,
            drawFrame: { _ in calls.value += 1 },
            to: destinationURL.url,
            as: .mp4
        )

        #expect(calls.value == 10)
    }

    @Test func test_draw_frame_export_cancellation() async throws {
        let sourceURL = resourceURL(named: "test-720p-h264-24fps.mov")
        let destinationURL = makeTemporaryURL()
        let subject = ExportSession()
        let task = Task {
            try await subject.export(
                asset: AVURLAsset(url: sourceURL),
                video: .codec(.h264, width: 1280, height: 720),
                drawFrame: { frame in
                    fillWhite(CGRect(x: 0, y: 0, width: 40, height: 40), in: frame.pixelBuffer)
                },
                to: destinationURL.url,
                as: .mov
            )
            Issue.record("Task should be cancelled long before we get here")
        }
        for await progress in subject.progressStream where progress > 0 {
            break
        }
        task.cancel()
        try? await task.value
    }

    // MARK: - Helpers

    struct FrameFacts {
        let pixelFormat: OSType
        let colorPrimaries: String
        let transferFunction: String
        let yCbCrMatrix: String

        let isMetalCompatible: Bool

        init(_ frame: VideoFrame) {
            pixelFormat = CVPixelBufferGetPixelFormatType(frame.pixelBuffer)
            colorPrimaries = frame.colorPrimaries
            transferFunction = frame.transferFunction
            yCbCrMatrix = frame.yCbCrMatrix
            isMetalCompatible = Self.canMakeTexture(from: frame.pixelBuffer)
        }

        private static func canMakeTexture(from pixelBuffer: CVPixelBuffer) -> Bool {
            guard let device = MTLCreateSystemDefaultDevice() else { return false }

            var textureCache: CVMetalTextureCache?
            CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
            guard let textureCache else { return false }

            let is10Bit = CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            var texture: CVMetalTexture?
            let result = CVMetalTextureCacheCreateTextureFromImage(
                nil,
                textureCache,
                pixelBuffer,
                nil,
                is10Bit ? .r16Unorm : .r8Unorm,
                CVPixelBufferGetWidthOfPlane(pixelBuffer, 0),
                CVPixelBufferGetHeightOfPlane(pixelBuffer, 0),
                0,
                &texture
            )
            return result == kCVReturnSuccess
        }
    }

    private func makeScalingComposition(
        of url: URL,
        to size: CGSize,
        hdr: Bool
    ) async throws -> sending (AVMutableComposition, AVMutableVideoComposition) {
        let asset = makeAsset(url: url)
        let sourceTrack = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let (duration, naturalSize) = try await (asset.load(.duration), sourceTrack.load(.naturalSize))
        let composition = AVMutableComposition()
        let track = try #require(composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ))
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceTrack, at: .zero)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layerInstruction.setTransform(
            CGAffineTransform(scaleX: size.width / naturalSize.width, y: size.height / naturalSize.height),
            at: .zero
        )
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layerInstruction]
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        if hdr {
            videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_2020
            videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_2100_HLG
            videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_2020
        }
        return (composition, videoComposition)
    }

    private func countFrames(of url: URL) async throws -> Int {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        reader.startReading()
        var count = 0
        while let sample = output.copyNextSampleBuffer() {
            count += CMSampleBufferGetNumSamples(sample)
        }
        return count
    }
}
