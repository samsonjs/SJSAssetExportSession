//
//  FrameScaler.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2026-11-07.
//

import Accelerate
import CoreVideo

/// Scales the composition's frames to the output size with vImage's high-quality resampling.
///
/// It works on the luma and chroma planes of the bi-planar video-range YCbCr frames the reader
/// hands over, so there's no colour conversion to get wrong. The built-in compositor, and
/// VideoToolbox on YCbCr frames, alias or blur noticeably more when scaling down.
final class FrameScaler {
    let size: CGSize
    let mode: VideoOutputSettings.ScaleMode
    private var pool: CVPixelBufferPool?

    init(size: CGSize, mode: VideoOutputSettings.ScaleMode) {
        self.size = size
        self.mode = mode
    }

    func scale(_ source: CVPixelBuffer) throws -> CVPixelBuffer {
        let format = CVPixelBufferGetPixelFormatType(source)
        let isTenBit = switch format {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: false
        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange: true
        default: throw ExportSession.Error.writeFailure(nil)
        }

        let pool = try pool ?? makePool(format: format)
        self.pool = pool
        var destination: CVPixelBuffer?
        try check(CVPixelBufferPoolCreatePixelBuffer(nil, pool, &destination))
        guard let destination else { throw ExportSession.Error.writeFailure(nil) }

        CVBufferPropagateAttachments(source, destination)
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(destination, [])
        defer {
            CVPixelBufferUnlockBaseAddress(destination, [])
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
        }

        let layout = ScaleLayout(
            source: CGSize(width: CVPixelBufferGetWidth(source), height: CVPixelBufferGetHeight(source)),
            destination: size,
            mode: mode
        )
        if layout.destinationRect.size != size {
            fillBlack(destination, isTenBit: isTenBit)
        }
        let flags = vImage_Flags(kvImageHighQualityResampling)
        var sourceLuma = source.plane(0, rect: layout.sourceRect, bytesPerPixel: isTenBit ? 2 : 1)
        var destinationLuma = destination.plane(0, rect: layout.destinationRect, bytesPerPixel: isTenBit ? 2 : 1)
        var sourceChroma = source.plane(1, rect: layout.sourceRect.halved, bytesPerPixel: isTenBit ? 4 : 2)
        var destinationChroma = destination.plane(1, rect: layout.destinationRect.halved, bytesPerPixel: isTenBit ? 4 : 2)
        if isTenBit {
            try check(vImageScale_Planar16U(&sourceLuma, &destinationLuma, nil, flags))
            try check(vImageScale_CbCr16U(&sourceChroma, &destinationChroma, nil, flags))
        } else {
            try check(vImageScale_Planar8(&sourceLuma, &destinationLuma, nil, flags))
            try check(vImageScale_CbCr8(&sourceChroma, &destinationChroma, nil, flags))
        }
        return destination
    }

    /// Video-range black: luma 16 and both chroma 128, in the high bits for 10-bit frames.
    private func fillBlack(_ buffer: CVPixelBuffer, isTenBit: Bool) {
        for (plane, value) in [(0, 16), (1, 128)] {
            let base = CVPixelBufferGetBaseAddressOfPlane(buffer, plane)!
            let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)
            let height = CVPixelBufferGetHeightOfPlane(buffer, plane)
            if isTenBit {
                let samples = rowBytes / 2
                for row in 0 ..< height {
                    base.advanced(by: row * rowBytes).assumingMemoryBound(to: UInt16.self)
                        .update(repeating: UInt16(value << 8), count: samples)
                }
            } else {
                for row in 0 ..< height {
                    base.advanced(by: row * rowBytes).initializeMemory(as: UInt8.self, repeating: UInt8(value), count: rowBytes)
                }
            }
        }
    }

    private func makePool(format: OSType) throws -> CVPixelBufferPool {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: format,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
        var pool: CVPixelBufferPool?
        try check(CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool))
        guard let pool else { throw ExportSession.Error.writeFailure(nil) }

        return pool
    }

    private func check(_ status: CVReturn) throws {
        guard status == kCVReturnSuccess else {
            throw ExportSession.Error.writeFailure(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }

    private func check(_ error: vImage_Error) throws {
        guard error == kvImageNoError else {
            throw ExportSession.Error.writeFailure(NSError(domain: NSOSStatusErrorDomain, code: error))
        }
    }
}

/// Which part of the source is scaled into which part of the output, in whole even pixels so
/// both 4:2:0 planes line up.
struct ScaleLayout {
    let sourceRect: CGRect
    let destinationRect: CGRect

    init(source: CGSize, destination: CGSize, mode: VideoOutputSettings.ScaleMode) {
        let widthRatio = destination.width / source.width
        let heightRatio = destination.height / source.height
        switch mode {
        case .fit:
            let scale = min(widthRatio, heightRatio)
            let size = CGSize(
                width: min(destination.width, Self.even(source.width * scale)),
                height: min(destination.height, Self.even(source.height * scale))
            )
            sourceRect = CGRect(origin: .zero, size: source)
            destinationRect = Self.centred(size, in: destination)
        case .fill:
            let scale = max(widthRatio, heightRatio)
            let size = CGSize(
                width: min(source.width, Self.even(destination.width / scale)),
                height: min(source.height, Self.even(destination.height / scale))
            )
            sourceRect = Self.centred(size, in: source)
            destinationRect = CGRect(origin: .zero, size: destination)
        case .stretch:
            sourceRect = CGRect(origin: .zero, size: source)
            destinationRect = CGRect(origin: .zero, size: destination)
        }
    }

    private static func even(_ value: CGFloat) -> CGFloat {
        max(2, (value / 2).rounded() * 2)
    }

    private static func centred(_ size: CGSize, in container: CGSize) -> CGRect {
        CGRect(
            x: ((container.width - size.width) / 4).rounded(.down) * 2,
            y: ((container.height - size.height) / 4).rounded(.down) * 2,
            width: size.width,
            height: size.height
        )
    }
}

private extension CGRect {
    /// The same area in a plane subsampled by two in both directions. An odd length rounds up
    /// because that's how the plane itself is sized.
    var halved: CGRect {
        CGRect(x: minX / 2, y: minY / 2, width: (width / 2).rounded(.up), height: (height / 2).rounded(.up))
    }
}

private extension CVPixelBuffer {
    /// A region of a locked plane, as a vImage buffer pointing into it.
    func plane(_ index: Int, rect: CGRect, bytesPerPixel: Int) -> vImage_Buffer {
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(self, index)
        let base = CVPixelBufferGetBaseAddressOfPlane(self, index)!
        let offset = Int(rect.minY) * rowBytes + Int(rect.minX) * bytesPerPixel
        return vImage_Buffer(
            data: base.advanced(by: offset),
            height: vImagePixelCount(rect.height),
            width: vImagePixelCount(rect.width),
            rowBytes: rowBytes
        )
    }
}
