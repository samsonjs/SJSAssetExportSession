//
//  FrameScalerTests.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2026-11-08.
//

import AVFoundation
@testable import SJSAssetExportSession
import Testing

struct FrameScalerTests {
    private static let formats = [
        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
    ]

    private static let lumaBlack: UInt16 = 16 << 8
    private static let lumaGrey: UInt16 = 126 << 8
    private static let neutralChroma: UInt16 = 128 << 8

    // In each of these the picture covers the whole 161×91 output, so no bars hide the last
    // chroma column and row.
    @Test(arguments: formats, [
        (VideoOutputSettings.ScaleMode.stretch, CGSize(width: 320, height: 180)),
        (.fill, CGSize(width: 320, height: 180)),
        (.fit, CGSize(width: 322, height: 182)),
    ])
    func test_odd_output_size_writes_every_chroma_sample(
        format: OSType,
        scaling: (mode: VideoOutputSettings.ScaleMode, source: CGSize)
    ) throws {
        let subject = FrameScaler(size: CGSize(width: 161, height: 91), mode: scaling.mode)

        let scaled = try subject.scale(makeGreyFrame(format: format, size: scaling.source))

        #expect(samples(of: scaled, plane: 1).allSatisfy { isClose($0, to: Self.neutralChroma) })
    }

    @Test(arguments: formats)
    func test_fit_fills_bars_with_video_range_black(format: OSType) throws {
        let subject = FrameScaler(size: CGSize(width: 180, height: 180), mode: .fit)

        let scaled = try subject.scale(makeGreyFrame(format: format, size: CGSize(width: 320, height: 180)))

        let luma = samples(of: scaled, plane: 0)
        #expect(luma.prefix(180).allSatisfy { $0 == Self.lumaBlack })
        #expect(isClose(luma[90 * 180 + 90], to: Self.lumaGrey))
        #expect(samples(of: scaled, plane: 1).prefix(180).allSatisfy { $0 == Self.neutralChroma })
    }

    private func isClose(_ sample: UInt16, to expected: UInt16) -> Bool {
        abs(Int(sample) - Int(expected)) <= 0x200
    }

    /// Solid grey with neutral chroma, so anything else in the scaled frame came from the scaler.
    private func makeGreyFrame(format: OSType, size: CGSize) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(size.width), Int(size.height), format, nil, &pixelBuffer)
        let frame = try #require(pixelBuffer)
        CVPixelBufferLockBaseAddress(frame, [])
        defer { CVPixelBufferUnlockBaseAddress(frame, []) }

        for (plane, value) in [(0, Self.lumaGrey), (1, Self.neutralChroma)] {
            let base = try #require(CVPixelBufferGetBaseAddressOfPlane(frame, plane))
            let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(frame, plane)
            for row in 0 ..< CVPixelBufferGetHeightOfPlane(frame, plane) {
                let start = base.advanced(by: row * rowBytes)
                if format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange {
                    start.initializeMemory(as: UInt16.self, repeating: value, count: rowBytes / 2)
                } else {
                    start.initializeMemory(as: UInt8.self, repeating: UInt8(value >> 8), count: rowBytes)
                }
            }
        }
        return frame
    }

    /// Every sample in a plane, row by row and without padding, with 8-bit samples moved into the
    /// high bits so both formats compare the same way.
    private func samples(of frame: CVPixelBuffer, plane: Int) -> [UInt16] {
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }

        let base = CVPixelBufferGetBaseAddressOfPlane(frame, plane)!
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(frame, plane)
        let samplesPerRow = CVPixelBufferGetWidthOfPlane(frame, plane) * (plane == 0 ? 1 : 2)
        let isTenBit = CVPixelBufferGetPixelFormatType(frame) == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        return (0 ..< CVPixelBufferGetHeightOfPlane(frame, plane)).flatMap { row in
            let start = base.advanced(by: row * rowBytes)
            return (0 ..< samplesPerRow).map { index in
                isTenBit
                    ? start.load(fromByteOffset: index * 2, as: UInt16.self)
                    : UInt16(start.load(fromByteOffset: index, as: UInt8.self)) << 8
            }
        }
    }
}
