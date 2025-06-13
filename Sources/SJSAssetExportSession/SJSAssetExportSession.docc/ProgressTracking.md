# Progress Tracking

Monitor export progress using `AsyncStream<Float>` for real-time feedback.

## Basic Usage

```swift
let exporter = ExportSession()

Task {
    for await progress in exporter.progressStream {
        // Progress ranges from 0.0 to 1.0
        print("Export progress: \(Int(progress * 100))%")
    }
}

try await exporter.export(...)
```

## UI Integration

### UIKit

```swift
Task { @MainActor in
    for await progress in exporter.progressStream {
        progressView.progress = progress
        progressLabel.text = "\(Int(progress * 100))%"
    }
}
```

### SwiftUI

```swift
@State private var progress: Float = 0.0

// In your view
ProgressView("Exporting...", value: progress, total: 1.0)

// Update progress
Task { @MainActor in
    for await progressValue in exporter.progressStream {
        progress = progressValue
    }
}
```

## Time Estimation

```swift
class ProgressTracker {
    private let startTime = Date()
    
    func timeRemaining(for progress: Float) -> TimeInterval? {
        guard progress > 0 else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed * Double(1.0 - progress) / Double(progress)
    }
}
```

## Cancellation

```swift
private var exportTask: Task<Void, Error>?

func startExport() {
    exportTask = Task {
        let exporter = ExportSession()
        
        Task { @MainActor in
            for await progress in exporter.progressStream {
                updateProgress(progress)
            }
        }
        
        try await exporter.export(...)
    }
}

func cancelExport() {
    exportTask?.cancel()
    exportTask = nil
}
```

## Throttling Updates

```swift
Task {
    var lastUpdate = Date()
    for await progress in exporter.progressStream {
        let now = Date()
        if now.timeIntervalSince(lastUpdate) > 0.1 { // 100ms throttle
            await MainActor.run { updateUI(progress) }
            lastUpdate = now
        }
    }
}
```

## Batch Export Progress

```swift
func exportMultipleFiles(_ files: [AVAsset]) async throws {
    for (index, asset) in files.enumerated() {
        let exporter = ExportSession()
        
        Task { @MainActor in
            for await progress in exporter.progressStream {
                let overallProgress = (Float(index) + progress) / Float(files.count)
                updateOverallProgress(overallProgress)
            }
        }
        
        try await exporter.export(asset: asset, ...)
    }
}
```

## See Also

- ``ExportSession`` - Main export class