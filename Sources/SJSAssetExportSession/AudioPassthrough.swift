//
//  AudioPassthrough.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2026-11-27.
//

import AVFoundation

/// One reader output and the writer input its samples go to.
final class Lane {
    let output: AVAssetReaderOutput
    let input: AVAssetWriterInput
    var isFinished = false

    init(output: AVAssetReaderOutput, input: AVAssetWriterInput) {
        self.output = output
        self.input = input
    }
}

/// Copies an asset's audio tracks to the output without decoding them.
///
/// Each audio track gets its own writer input, enabled or not as the source track is, with its language. Tracks the
/// source groups as alternates are grouped in the output too, and so are tracks linked by an audio fallback
/// association, which is copied as well. An `AVComposition` has no track groups of its own, so the association is
/// how one can say which of its tracks are alternates. Timed metadata tracks that describe a copied audio track,
/// such as the `com.apple.quicktime.cinematic-audio` track iPhones write for their spatial audio track, are copied
/// with the association that says which track they describe.
enum AudioPassthrough {
    typealias Error = ExportSession.Error

    static func addLanes(
        from asset: AVAsset,
        to reader: AVAssetReader,
        and writer: AVAssetWriter
    ) async throws -> [Lane] {
        var lanes: [Lane] = []
        var inputs: [CMPersistentTrackID: AVAssetWriterInput] = [:]
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        for track in audioTracks {
            let (formats, isEnabled, languageCode, extendedLanguageTag) = try await track.load(
                .formatDescriptions, .isEnabled, .languageCode, .extendedLanguageTag
            )
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else { throw Error.setupFailure(.cannotAddAudioOutput) }

            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: formats.first)
            input.expectsMediaDataInRealTime = false
            input.marksOutputTrackAsEnabled = isEnabled
            input.languageCode = languageCode
            input.extendedLanguageTag = extendedLanguageTag
            guard writer.canAdd(input) else { throw Error.setupFailure(.cannotAddAudioInput) }

            reader.add(output)
            writer.add(input)
            inputs[track.trackID] = input
            lanes.append(Lane(output: output, input: input))
        }

        let fallbacks = try await addFallbackAssociations(among: audioTracks, inputs: inputs)
        try await addGroups(
            sourceGroups: asset.load(.trackGroups).map { $0.trackIDs.map(\.int32Value) },
            fallbacks: fallbacks,
            order: audioTracks.map(\.trackID),
            inputs: inputs,
            writer: writer
        )
        try await lanes.append(contentsOf: addDescribingMetadata(from: asset, inputs: inputs, reader: reader, writer: writer))
        return lanes
    }

    /// Copies each audio fallback association, returning the pairs of track IDs it linked.
    private static func addFallbackAssociations(
        among tracks: [AVAssetTrack],
        inputs: [CMPersistentTrackID: AVAssetWriterInput]
    ) async throws -> [(CMPersistentTrackID, CMPersistentTrackID)] {
        let type = AVAssetTrack.AssociationType.audioFallback.rawValue
        var pairs: [(CMPersistentTrackID, CMPersistentTrackID)] = []
        for track in tracks {
            guard let input = inputs[track.trackID] else { continue }
            for fallback in try await track.loadAssociatedTracks(ofType: .audioFallback) {
                guard let fallbackInput = inputs[fallback.trackID],
                      input.canAddTrackAssociation(withTrackOf: fallbackInput, type: type)
                else { continue }
                input.addTrackAssociation(withTrackOf: fallbackInput, type: type)
                pairs.append((track.trackID, fallback.trackID))
            }
        }
        return pairs
    }

    /// Groups the copied audio tracks as alternates the way the source does, and with whatever they fall back to.
    private static func addGroups(
        sourceGroups: [[CMPersistentTrackID]],
        fallbacks: [(CMPersistentTrackID, CMPersistentTrackID)],
        order: [CMPersistentTrackID],
        inputs: [CMPersistentTrackID: AVAssetWriterInput],
        writer: AVAssetWriter
    ) throws {
        let links = sourceGroups.map { $0.filter { inputs[$0] != nil } } + fallbacks.map { [$0.0, $0.1] }
        for group in alternates(linking: links, order: order) where group.count > 1 {
            let groupInputs = group.compactMap { inputs[$0] }
            let defaultInput = groupInputs.first { $0.marksOutputTrackAsEnabled }
            let inputGroup = AVAssetWriterInputGroup(inputs: groupInputs, defaultInput: defaultInput)
            guard writer.canAdd(inputGroup) else { throw Error.setupFailure(.cannotAddAudioInput) }
            writer.add(inputGroup)
        }
    }

    /// Merges sets of track IDs that share a track, keeping each set in `order`.
    static func alternates(
        linking links: [[CMPersistentTrackID]],
        order: [CMPersistentTrackID]
    ) -> [[CMPersistentTrackID]] {
        var groups: [Set<CMPersistentTrackID>] = []
        for link in links where !link.isEmpty {
            var merged = Set(link)
            groups.removeAll { group in
                guard !group.isDisjoint(with: merged) else { return false }
                merged.formUnion(group)
                return true
            }
            groups.append(merged)
        }
        return groups
            .map { group in order.filter(group.contains) }
            .sorted { (order.firstIndex(of: $0[0]) ?? 0) < (order.firstIndex(of: $1[0]) ?? 0) }
    }

    /// Copies the timed metadata tracks that describe a copied audio track, and nothing else.
    private static func addDescribingMetadata(
        from asset: AVAsset,
        inputs: [CMPersistentTrackID: AVAssetWriterInput],
        reader: AVAssetReader,
        writer: AVAssetWriter
    ) async throws -> [Lane] {
        guard !inputs.isEmpty else { return [] }

        let type = AVAssetTrack.AssociationType.metadataReferent.rawValue
        var lanes: [Lane] = []
        for track in try await asset.loadTracks(withMediaType: .metadata) {
            let described = try await track.loadAssociatedTracks(ofType: .metadataReferent)
                .compactMap { inputs[$0.trackID] }
            guard !described.isEmpty else { continue }

            let formats = try await track.load(.formatDescriptions)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            output.alwaysCopiesSampleData = false
            let input = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: formats.first)
            input.expectsMediaDataInRealTime = false
            guard reader.canAdd(output), writer.canAdd(input) else { continue }

            reader.add(output)
            writer.add(input)
            for audioInput in described where input.canAddTrackAssociation(withTrackOf: audioInput, type: type) {
                input.addTrackAssociation(withTrackOf: audioInput, type: type)
            }
            lanes.append(Lane(output: output, input: input))
        }
        return lanes
    }
}
