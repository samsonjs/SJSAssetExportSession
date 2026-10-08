//
//  VideoFrame.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2026-10-07.
//

public import AVFoundation

/// A video frame on its way to the encoder, handed to a ``FrameArtist`` to draw into.
public struct VideoFrame {
    /// The frame's pixels, writable until the artist returns.
    ///
    /// The buffer is bi-planar 4:2:0 video-range YCbCr: 10-bit
    /// (`kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange`) when the composition's transfer
    /// function is HLG or PQ, and 8-bit (`kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`)
    /// otherwise. It's IOSurface-backed and Metal-compatible.
    public let pixelBuffer: CVPixelBuffer

    /// When the frame is shown in the exported video.
    public let presentationTime: CMTime

    /// The composition's colour primaries, one of the `AVVideoColorPrimaries_*` constants.
    /// Defaults to BT.2020 for HDR compositions and BT.709 otherwise when the composition
    /// doesn't say.
    public let colorPrimaries: String

    /// The composition's transfer function, one of the `AVVideoTransferFunction_*` constants.
    /// Defaults to BT.709 when the composition doesn't say.
    public let transferFunction: String

    /// The composition's YCbCr matrix, one of the `AVVideoYCbCrMatrix_*` constants. Defaults
    /// to BT.2020 for HDR compositions and BT.709 otherwise when the composition doesn't say.
    public let yCbCrMatrix: String
}

/// Draws into each video frame of an export, in place, before it's encoded.
///
/// The artist is called once for every frame written, in presentation order, one call at a
/// time on the export's queue and inside an autorelease pool per frame. It never runs
/// concurrently with itself, so it can keep state without a lock. The frame is appended to the
/// writer as soon as the artist returns, so any GPU work drawing into it has to be complete by
/// then, not just committed. Audio is written on the same queue, so a slow artist slows the
/// whole export.
///
/// Don't let anything hold on to a frame after the artist returns. A `CVMetalTextureCache`
/// keeps every texture it makes, and the frame behind it, for its maximum texture age: about
/// a second by default, which at 4K is hundreds of megabytes. Make textures with
/// `MTLDevice.makeTexture(descriptor:iosurface:plane:)` instead, or set the cache's
/// `kCVMetalTextureCacheMaximumTextureAgeKey` to 0 and flush it after each frame.
///
/// An error thrown by the artist stops the export, and ``ExportSession`` rethrows it as is.
///
/// The artist runs on the export's queue, not the caller's actor. It's passed as `sending`, so
/// it can capture state that isn't `Sendable`, like a Metal texture cache, as long as nothing
/// else uses that state once the export starts. When the compiler says sending it risks data
/// races, it captures something that still belongs to an actor, like a property of a main
/// actor object. Create that state in a `nonisolated` function that returns
/// `sending FrameArtist` instead.
public typealias FrameArtist = (VideoFrame) throws -> Void

struct FrameColour {
    let colorPrimaries: String
    let transferFunction: String
    let yCbCrMatrix: String

    init(of videoComposition: AVVideoComposition) {
        let isHDR = videoComposition.isHDR
        colorPrimaries = videoComposition.colorPrimaries
            ?? (isHDR ? AVVideoColorPrimaries_ITU_R_2020 : AVVideoColorPrimaries_ITU_R_709_2)
        transferFunction = videoComposition.colorTransferFunction ?? AVVideoTransferFunction_ITU_R_709_2
        yCbCrMatrix = videoComposition.colorYCbCrMatrix
            ?? (isHDR ? AVVideoYCbCrMatrix_ITU_R_2020 : AVVideoYCbCrMatrix_ITU_R_709_2)
    }
}

extension VideoFrame {
    init(pixelBuffer: CVPixelBuffer, presentationTime: CMTime, colour: FrameColour) {
        self.init(
            pixelBuffer: pixelBuffer,
            presentationTime: presentationTime,
            colorPrimaries: colour.colorPrimaries,
            transferFunction: colour.transferFunction,
            yCbCrMatrix: colour.yCbCrMatrix
        )
    }
}
