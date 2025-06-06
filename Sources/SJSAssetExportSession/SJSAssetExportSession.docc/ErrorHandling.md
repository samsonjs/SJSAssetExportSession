# Error Handling

Learn how to properly handle errors and troubleshoot common issues with SJSAssetExportSession.

## Overview

SJSAssetExportSession provides comprehensive error reporting through the ``ExportSession/Error`` enum. This guide covers how to handle different types of errors and recover from common failure scenarios.

## Error Types

### ExportSession.Error

The main error type with three categories:

```swift
public enum Error: LocalizedError, Equatable {
    case setupFailure(SetupFailureReason)
    case readFailure((any Swift.Error)?)
    case writeFailure((any Swift.Error)?)
}
```

## Setup Failures

Setup failures occur during export initialization, before any media processing begins.

### Common Setup Failures

```swift
do {
    try await exporter.export(
        asset: sourceAsset,
        video: .codec(.h264, width: 1920, height: 1080),
        to: destinationURL,
        as: .mp4
    )
} catch ExportSession.Error.setupFailure(let reason) {
    switch reason {
    case .videoTracksEmpty:
        print("Source asset has no video tracks")
    case .audioSettingsEmpty:
        print("Audio settings dictionary is empty")
    case .audioSettingsInvalid:
        print("Audio settings are not valid for this format")
    case .videoSettingsInvalid:
        print("Video settings are not valid for this format")
    case .cannotAddAudioInput:
        print("Cannot add audio input to the writer")
    case .cannotAddAudioOutput:
        print("Cannot add audio output to the reader")
    case .cannotAddVideoInput:
        print("Cannot add video input to the writer")
    case .cannotAddVideoOutput:
        print("Cannot add video output to the reader")
    }
}
```

### Handling Setup Failures

#### No Video Tracks
```swift
// Check for video tracks before export
let videoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
guard !videoTracks.isEmpty else {
    print("Asset has no video tracks - cannot export")
    return
}
```

#### Invalid Settings
```swift
// Validate settings compatibility
do {
    let writer = try AVAssetWriter(outputURL: tempURL, fileType: .mp4)
    let videoSettings = VideoOutputSettings.codec(.h264, width: 1920, height: 1080).settingsDictionary
    
    guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else {
        print("Video settings are not compatible with MP4 format")
        return
    }
} catch {
    print("Failed to create writer: \(error)")
}
```

## Read Failures

Read failures occur when the asset reader encounters problems reading the source media.

### Handling Read Failures

```swift
do {
    try await exporter.export(/* ... */)
} catch ExportSession.Error.readFailure(let underlyingError) {
    if let error = underlyingError {
        print("Read failed: \(error.localizedDescription)")
        
        // Handle specific AVFoundation errors
        if let avError = error as? AVError {
            switch avError.code {
            case .fileFormatNotRecognized:
                print("File format not supported")
            case .mediaServicesWereReset:
                print("Media services were reset - retry may succeed")
            case .diskFull:
                print("Not enough disk space")
            default:
                print("AVFoundation error: \(avError.localizedDescription)")
            }
        }
    } else {
        print("Unknown read failure")
    }
}
```

### Common Read Failure Causes

- Corrupted source files
- Unsupported file formats
- Permission issues
- Network interruption (for remote assets)
- Media services restart

## Write Failures

Write failures occur when the asset writer cannot write to the destination.

### Handling Write Failures

```swift
do {
    try await exporter.export(/* ... */)
} catch ExportSession.Error.writeFailure(let underlyingError) {
    if let error = underlyingError {
        print("Write failed: \(error.localizedDescription)")
        
        if let avError = error as? AVError {
            switch avError.code {
            case .diskFull:
                print("Not enough disk space for export")
            case .fileAlreadyExists:
                print("Destination file already exists")
            case .noPermission:
                print("No permission to write to destination")
            default:
                print("Write error: \(avError.localizedDescription)")
            }
        }
    } else {
        print("Unknown write failure")
    }
}
```

### Common Write Failure Causes

- Insufficient disk space
- File permissions
- Destination file already exists
- Invalid destination path
- Unsupported format combination

## Comprehensive Error Handling

### Complete Error Handling Pattern

```swift
func exportVideoWithErrorHandling() async {
    do {
        let exporter = ExportSession()
        
        // Optional: Monitor progress
        Task {
            for await progress in exporter.progressStream {
                print("Progress: \(Int(progress * 100))%")
            }
        }
        
        try await exporter.export(
            asset: sourceAsset,
            video: .codec(.h264, width: 1920, height: 1080),
            to: destinationURL,
            as: .mp4
        )
        
        print("Export completed successfully!")
        
    } catch let error as ExportSession.Error {
        handleExportError(error)
    } catch {
        print("Unexpected error: \(error.localizedDescription)")
    }
}

private func handleExportError(_ error: ExportSession.Error) {
    switch error {
    case .setupFailure(let reason):
        print("Setup failed: \(reason.description)")
        // Could show user-friendly message based on reason
        
    case .readFailure(let underlyingError):
        print("Failed to read source: \(underlyingError?.localizedDescription ?? "Unknown")")
        // Could suggest checking source file
        
    case .writeFailure(let underlyingError):
        print("Failed to write output: \(underlyingError?.localizedDescription ?? "Unknown")")
        // Could suggest checking disk space or permissions
    }
}
```

## Retry Strategies

### Automatic Retry with Backoff

```swift
func exportWithRetry(maxAttempts: Int = 3) async throws {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            try await exporter.export(
                asset: sourceAsset,
                video: .codec(.h264, width: 1920, height: 1080),
                to: destinationURL,
                as: .mp4
            )
            return // Success!
            
        } catch let error as ExportSession.Error {
            lastError = error
            
            // Only retry for certain types of failures
            switch error {
            case .readFailure(let underlyingError):
                if let avError = underlyingError as? AVError,
                   avError.code == .mediaServicesWereReset {
                    print("Media services reset, retrying... (attempt \(attempt))")
                    try await Task.sleep(for: .seconds(1))
                    continue
                }
                throw error
                
            case .writeFailure(let underlyingError):
                if let avError = underlyingError as? AVError,
                   avError.code == .diskFull {
                    print("Disk full - cannot retry")
                    throw error
                }
                // Other write failures might be transient
                print("Write failed, retrying... (attempt \(attempt))")
                try await Task.sleep(for: .seconds(2))
                continue
                
            case .setupFailure:
                // Setup failures are usually permanent
                throw error
            }
        }
    }
    
    throw lastError ?? ExportSession.Error.setupFailure(.videoTracksEmpty)
}
```

## Cancellation Handling

### Handling Task Cancellation

```swift
func exportWithCancellation() async throws {
    let exporter = ExportSession()
    
    do {
        try await exporter.export(
            asset: sourceAsset,
            video: .codec(.h264, width: 1920, height: 1080),
            to: destinationURL,
            as: .mp4
        )
    } catch is CancellationError {
        print("Export was cancelled")
        // Clean up partial files if needed
        try? FileManager.default.removeItem(at: destinationURL)
    }
}

// Cancel from another task
let exportTask = Task {
    try await exportWithCancellation()
}

// Later...
exportTask.cancel()
```

## Validation Before Export

### Pre-Export Validation

```swift
func validateBeforeExport(asset: AVAsset, destinationURL: URL) async throws {
    // Check video tracks
    let videoTracks = try await asset.loadTracks(withMediaType: .video)
    guard !videoTracks.isEmpty else {
        throw ExportSession.Error.setupFailure(.videoTracksEmpty)
    }
    
    // Check disk space
    let resourceValues = try destinationURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
    if let availableCapacity = resourceValues.volumeAvailableCapacity {
        let estimatedSize = try await estimateOutputSize(for: asset)
        guard availableCapacity > estimatedSize else {
            throw ExportSession.Error.writeFailure(AVError(.diskFull))
        }
    }
    
    // Check destination directory exists
    let destinationDir = destinationURL.deletingLastPathComponent()
    guard FileManager.default.fileExists(atPath: destinationDir.path) else {
        throw ExportSession.Error.writeFailure(AVError(.fileNotFound))
    }
    
    // Check write permissions
    guard FileManager.default.isWritableFile(atPath: destinationDir.path) else {
        throw ExportSession.Error.writeFailure(AVError(.noPermission))
    }
}

private func estimateOutputSize(for asset: AVAsset) async throws -> Int64 {
    let duration = try await asset.load(.duration)
    let durationSeconds = duration.seconds
    
    // Rough estimate: 5 Mbps for 1080p H.264
    let estimatedBitrate = 5_000_000 // bits per second
    let estimatedBytes = Int64(durationSeconds * Double(estimatedBitrate) / 8)
    
    return estimatedBytes
}
```

## User-Friendly Error Messages

### Providing Helpful Messages

```swift
func userFriendlyErrorMessage(for error: ExportSession.Error) -> String {
    switch error {
    case .setupFailure(.videoTracksEmpty):
        return "The selected file doesn't contain any video content."
        
    case .setupFailure(.audioSettingsInvalid):
        return "The audio settings are not compatible with the selected format."
        
    case .setupFailure(.videoSettingsInvalid):
        return "The video settings are not compatible with the selected format."
        
    case .readFailure(let underlyingError):
        if let avError = underlyingError as? AVError {
            switch avError.code {
            case .fileFormatNotRecognized:
                return "The video file format is not supported."
            case .mediaServicesWereReset:
                return "Media services were interrupted. Please try again."
            default:
                return "Unable to read the source video file."
            }
        }
        return "Unable to read the source video file."
        
    case .writeFailure(let underlyingError):
        if let avError = underlyingError as? AVError {
            switch avError.code {
            case .diskFull:
                return "Not enough storage space to complete the export."
            case .noPermission:
                return "Permission denied. Check that you can write to the destination folder."
            default:
                return "Unable to save the exported video file."
            }
        }
        return "Unable to save the exported video file."
    }
}
```

## Debugging Tips

### Enable Detailed Logging

```swift
// Add logging to track export progress
let exporter = ExportSession()

Task {
    for await progress in exporter.progressStream {
        print("Export progress: \(String(format: "%.1f", progress * 100))%")
    }
}

print("Starting export...")
print("Source: \(sourceAsset)")
print("Destination: \(destinationURL)")

do {
    try await exporter.export(/* ... */)
    print("Export completed successfully")
} catch {
    print("Export failed: \(error)")
}
```

### Check Asset Properties

```swift
func debugAssetProperties(asset: AVAsset) async {
    do {
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        
        print("Asset duration: \(duration.seconds) seconds")
        print("Video tracks: \(videoTracks.count)")
        print("Audio tracks: \(audioTracks.count)")
        
        for (index, track) in videoTracks.enumerated() {
            let naturalSize = try await track.load(.naturalSize)
            let nominalFrameRate = try await track.load(.nominalFrameRate)
            print("Video track \(index): \(naturalSize) @ \(nominalFrameRate) fps")
        }
        
    } catch {
        print("Failed to load asset properties: \(error)")
    }
}
```

## See Also

- ``ExportSession/Error`` - Main error enum
- ``ExportSession/SetupFailureReason`` - Setup failure details
- <doc:GettingStarted> - Basic usage examples
- <doc:PerformanceOptimization> - Avoiding common performance issues