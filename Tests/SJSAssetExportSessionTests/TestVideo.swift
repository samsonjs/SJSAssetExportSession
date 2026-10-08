//
//  TestVideo.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2026-10-07.
//

import AVFoundation
import CoreGraphics
import Testing

/// A short, silent, solid blue H.264 video written for a test, so frames drawn over it are easy
/// to tell apart from the source.
struct TestVideo {
    static let size = CGSize(width: 320, height: 180)

    let url: AutoDestructingURL
    let fps: Int32
    let frameCount: Int

    var duration: CMTime {
        CMTime(value: CMTimeValue(frameCount), timescale: fps)
    }

    static func make(fps: Int32 = 30, frameCount: Int = 10) async throws -> TestVideo {
        let url = URL.temporaryDirectory.appending(component: "test-video-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        let frame = try makeBlueFrame()
        for index in 0 ..< frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            adaptor.append(frame, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: fps))
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: fps))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? TestVideoError.writeFailed }

        return TestVideo(url: AutoDestructingURL(url: url), fps: fps, frameCount: frameCount)
    }

    private static func makeBlueFrame() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        guard let pixelBuffer else { throw TestVideoError.writeFailed }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let base = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for y in 0 ..< Int(size.height) {
            for x in 0 ..< Int(size.width) {
                let offset = y * bytesPerRow + x * 4
                (base[offset], base[offset + 1], base[offset + 2], base[offset + 3]) = (255, 0, 0, 255)
            }
        }
        return pixelBuffer
    }
}

enum TestVideoError: Error {
    case writeFailed
}

/// A decoded frame's pixels, for checking what colour a spot came out.
struct DecodedFrame {
    enum Colour: Equatable {
        case white, black, blue, other
    }

    let width: Int
    let pixels: [UInt8]

    /// The frame shown at `time`, exactly.
    static func at(_ time: CMTime, in url: URL) async throws -> DecodedFrame {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: time).image
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return DecodedFrame(width: width, pixels: pixels)
    }

    /// The colour at `point`, measured from the top left.
    func colour(at point: CGPoint) -> Colour {
        let offset = (Int(point.y) * width + Int(point.x)) * 4
        let (r, g, b) = (pixels[offset], pixels[offset + 1], pixels[offset + 2])
        func high(_ v: UInt8) -> Bool { v > 180 }
        func low(_ v: UInt8) -> Bool { v < 70 }
        return switch (r, g, b) {
        case _ where high(r) && high(g) && high(b): .white
        case _ where low(r) && low(g) && low(b): .black
        case _ where low(r) && low(g) && high(b): .blue
        default: .other
        }
    }
}

/// Fills `rect` (from the top left) with white in a bi-planar video-range YCbCr frame, the way
/// an artist draws into a frame in place.
func fillWhite(_ rect: CGRect, in pixelBuffer: CVPixelBuffer) {
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    let is10Bit = CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
    let x0 = Int(rect.minX), x1 = Int(rect.maxX), y0 = Int(rect.minY), y1 = Int(rect.maxY)

    func fill(plane: Int, xs: Range<Int>, ys: Range<Int>, samplesPerPixel: Int, value: Int) {
        let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane)!
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
        for y in ys {
            for x in xs {
                for sample in 0 ..< samplesPerPixel {
                    let index = x * samplesPerPixel + sample
                    if is10Bit {
                        // 10 bits in the high bits of each 16-bit sample.
                        base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt16.self)[index] = UInt16(value << 2) << 6
                    } else {
                        base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)[index] = UInt8(value)
                    }
                }
            }
        }
    }

    // Video range white: Y 235, Cb and Cr 128.
    fill(plane: 0, xs: x0 ..< x1, ys: y0 ..< y1, samplesPerPixel: 1, value: 235)
    fill(plane: 1, xs: x0 / 2 ..< x1 / 2, ys: y0 / 2 ..< y1 / 2, samplesPerPixel: 2, value: 128)
}
