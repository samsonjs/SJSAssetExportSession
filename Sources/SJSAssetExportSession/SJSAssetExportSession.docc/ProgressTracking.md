# Progress Tracking

Learn how to monitor export progress and provide user feedback during video processing.

## Overview

SJSAssetExportSession provides real-time progress tracking through an `AsyncStream<Float>`. This allows you to create responsive user interfaces that show export progress, estimated time remaining, and handle user cancellation.

## Basic Progress Monitoring

### Simple Progress Tracking

```swift
let exporter = ExportSession()

Task {
    for await progress in exporter.progressStream {
        print("Export progress: \(Int(progress * 100))%")
    }
}

try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

### Progress Values

The progress stream yields `Float` values between `0.0` and `1.0`:
- `0.0`: Export has just started
- `0.5`: Export is halfway complete
- `1.0`: Export has finished successfully

## UI Integration

### UIKit Progress View

```swift
import UIKit

class ExportViewController: UIViewController {
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    
    private var exportTask: Task<Void, Error>?
    
    func startExport() {
        let exporter = ExportSession()
        
        exportTask = Task {
            // Monitor progress on main thread
            Task { @MainActor in
                for await progress in exporter.progressStream {
                    progressView.progress = progress
                    progressLabel.text = "\(Int(progress * 100))%"
                }
            }
            
            // Perform export
            try await exporter.export(
                asset: sourceAsset,
                video: .codec(.h264, width: 1920, height: 1080),
                to: destinationURL,
                as: .mp4
            )
            
            await MainActor.run {
                progressLabel.text = "Complete!"
                cancelButton.isEnabled = false
            }
        }
    }
    
    @IBAction func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
    }
}
```

### SwiftUI Progress View

```swift
import SwiftUI

struct ExportView: View {
    @State private var progress: Float = 0.0
    @State private var isExporting = false
    @State private var exportTask: Task<Void, Error>?
    
    var body: some View {
        VStack(spacing: 20) {
            if isExporting {
                ProgressView("Exporting...", value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                
                Button("Cancel") {
                    exportTask?.cancel()
                    exportTask = nil
                    isExporting = false
                }
                .foregroundColor(.red)
            } else {
                Button("Start Export") {
                    startExport()
                }
            }
        }
        .padding()
    }
    
    private func startExport() {
        isExporting = true
        progress = 0.0
        
        let exporter = ExportSession()
        
        exportTask = Task {
            // Monitor progress
            Task { @MainActor in
                for await progressValue in exporter.progressStream {
                    progress = progressValue
                }
            }
            
            do {
                try await exporter.export(
                    asset: sourceAsset,
                    video: .codec(.h264, width: 1920, height: 1080),
                    to: destinationURL,
                    as: .mp4
                )
                
                await MainActor.run {
                    isExporting = false
                    progress = 1.0
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    // Handle error
                }
            }
        }
    }
}
```

## Advanced Progress Features

### Time Estimation

```swift
class ExportProgressTracker {
    private var startTime: Date?
    private var lastProgressTime: Date?
    private var lastProgress: Float = 0.0
    
    func trackProgress(_ progress: Float) -> (timeElapsed: TimeInterval, timeRemaining: TimeInterval?) {
        let now = Date()
        
        if startTime == nil {
            startTime = now
        }
        
        let timeElapsed = now.timeIntervalSince(startTime!)
        
        // Calculate time remaining based on progress rate
        let timeRemaining: TimeInterval?
        if progress > 0 && progress != lastProgress {
            let progressRate = progress / Float(timeElapsed)
            let remainingProgress = 1.0 - progress
            timeRemaining = TimeInterval(remainingProgress / progressRate)
        } else {
            timeRemaining = nil
        }
        
        lastProgressTime = now
        lastProgress = progress
        
        return (timeElapsed, timeRemaining)
    }
}

// Usage
let progressTracker = ExportProgressTracker()

Task {
    for await progress in exporter.progressStream {
        let (elapsed, remaining) = progressTracker.trackProgress(progress)
        
        await MainActor.run {
            progressView.progress = progress
            progressLabel.text = "\(Int(progress * 100))%"
            
            if let remaining = remaining {
                timeLabel.text = "Time remaining: \(Int(remaining))s"
            }
        }
    }
}
```

### Progress with Detailed Status

```swift
enum ExportStatus {
    case preparing
    case encoding(Float)
    case finalizing
    case completed
    case failed(Error)
    case cancelled
}

class DetailedExportTracker: ObservableObject {
    @Published var status: ExportStatus = .preparing
    
    func startExport() {
        status = .preparing
        
        let exporter = ExportSession()
        
        Task {
            // Monitor progress
            Task { @MainActor in
                for await progress in exporter.progressStream {
                    if progress < 1.0 {
                        status = .encoding(progress)
                    } else {
                        status = .finalizing
                    }
                }
            }
            
            do {
                try await exporter.export(
                    asset: sourceAsset,
                    video: .codec(.h264, width: 1920, height: 1080),
                    to: destinationURL,
                    as: .mp4
                )
                
                await MainActor.run {
                    status = .completed
                }
            } catch is CancellationError {
                await MainActor.run {
                    status = .cancelled
                }
            } catch {
                await MainActor.run {
                    status = .failed(error)
                }
            }
        }
    }
}
```

## Batch Export Progress

### Multiple File Export

```swift
class BatchExportManager: ObservableObject {
    @Published var overallProgress: Float = 0.0
    @Published var currentFileProgress: Float = 0.0
    @Published var currentFileName: String = ""
    @Published var filesCompleted: Int = 0
    
    func exportFiles(_ files: [(asset: AVAsset, url: URL, name: String)]) async throws {
        let totalFiles = files.count
        
        for (index, file) in files.enumerated() {
            await MainActor.run {
                currentFileName = file.name
                currentFileProgress = 0.0
                filesCompleted = index
            }
            
            let exporter = ExportSession()
            
            // Track individual file progress
            Task { @MainActor in
                for await progress in exporter.progressStream {
                    currentFileProgress = progress
                    
                    // Calculate overall progress
                    let completedPortion = Float(index) / Float(totalFiles)
                    let currentPortion = progress / Float(totalFiles)
                    overallProgress = completedPortion + currentPortion
                }
            }
            
            try await exporter.export(
                asset: file.asset,
                video: .codec(.h264, width: 1920, height: 1080),
                to: file.url,
                as: .mp4
            )
        }
        
        await MainActor.run {
            overallProgress = 1.0
            filesCompleted = totalFiles
        }
    }
}
```

## Background Export Progress

### Handling Background Tasks

```swift
import BackgroundTasks

class BackgroundExportManager {
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    func startBackgroundExport() {
        // Request background time
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "VideoExport") {
            // Background time expired
            self.endBackgroundTask()
        }
        
        let exporter = ExportSession()
        
        Task {
            // Monitor progress with reduced frequency for background
            Task {
                var lastUpdate = Date()
                for await progress in exporter.progressStream {
                    let now = Date()
                    if now.timeIntervalSince(lastUpdate) > 1.0 { // Update every second
                        print("Background export progress: \(Int(progress * 100))%")
                        lastUpdate = now
                    }
                }
            }
            
            do {
                try await exporter.export(
                    asset: sourceAsset,
                    video: .codec(.h264, width: 1920, height: 1080),
                    to: destinationURL,
                    as: .mp4
                )
                
                print("Background export completed")
            } catch {
                print("Background export failed: \(error)")
            }
            
            endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
```

## Progress Persistence

### Saving Progress State

```swift
class PersistentExportManager {
    private let userDefaults = UserDefaults.standard
    private let progressKey = "export_progress"
    
    func saveProgress(_ progress: Float, for exportID: String) {
        userDefaults.set(progress, forKey: "\(progressKey)_\(exportID)")
    }
    
    func loadProgress(for exportID: String) -> Float {
        return userDefaults.float(forKey: "\(progressKey)_\(exportID)")
    }
    
    func clearProgress(for exportID: String) {
        userDefaults.removeObject(forKey: "\(progressKey)_\(exportID)")
    }
    
    func resumableExport(exportID: String) async throws {
        let savedProgress = loadProgress(for: exportID)
        
        if savedProgress > 0 {
            print("Resuming export from \(Int(savedProgress * 100))%")
        }
        
        let exporter = ExportSession()
        
        Task {
            for await progress in exporter.progressStream {
                saveProgress(progress, for: exportID)
                
                await MainActor.run {
                    // Update UI
                }
            }
        }
        
        try await exporter.export(
            asset: sourceAsset,
            video: .codec(.h264, width: 1920, height: 1080),
            to: destinationURL,
            as: .mp4
        )
        
        clearProgress(for: exportID)
    }
}
```

## Performance Considerations

### Throttling Progress Updates

```swift
func throttledProgressTracking() {
    let exporter = ExportSession()
    
    Task {
        var lastUpdate = Date()
        let updateInterval: TimeInterval = 0.1 // Update every 100ms
        
        for await progress in exporter.progressStream {
            let now = Date()
            if now.timeIntervalSince(lastUpdate) >= updateInterval {
                await MainActor.run {
                    progressView.progress = progress
                    progressLabel.text = "\(Int(progress * 100))%"
                }
                lastUpdate = now
            }
        }
    }
    
    try await exporter.export(/* ... */)
}
```

### Memory-Efficient Progress Tracking

```swift
func efficientProgressTracking() {
    let exporter = ExportSession()
    
    Task {
        // Use AsyncSequence operations to process progress efficiently
        for await progress in exporter.progressStream
            .compactMap { progress in
                // Only emit significant progress changes
                progress.isMultiple(of: 0.01) ? progress : nil
            } {
            await MainActor.run {
                updateProgress(progress)
            }
        }
    }
}
```

## Testing Progress Tracking

### Mock Progress Stream

```swift
extension ExportSession {
    static func mockProgressStream(duration: TimeInterval = 5.0) -> AsyncStream<Float> {
        AsyncStream { continuation in
            Task {
                let steps = 100
                let interval = duration / Double(steps)
                
                for step in 0...steps {
                    let progress = Float(step) / Float(steps)
                    continuation.yield(progress)
                    
                    if step < steps {
                        try await Task.sleep(for: .seconds(interval))
                    }
                }
                
                continuation.finish()
            }
        }
    }
}

// Usage in tests
func testProgressTracking() async {
    var progressValues: [Float] = []
    
    for await progress in ExportSession.mockProgressStream(duration: 1.0) {
        progressValues.append(progress)
    }
    
    XCTAssertEqual(progressValues.first, 0.0)
    XCTAssertEqual(progressValues.last, 1.0)
    XCTAssertTrue(progressValues.count > 50) // Should have many progress updates
}
```

## Common Patterns

### Progress with User Feedback

```swift
func exportWithFeedback() async throws {
    let exporter = ExportSession()
    let startTime = Date()
    
    Task { @MainActor in
        for await progress in exporter.progressStream {
            let elapsed = Date().timeIntervalSince(startTime)
            
            if progress > 0 {
                let estimatedTotal = elapsed / Double(progress)
                let remaining = estimatedTotal - elapsed
                
                progressLabel.text = """
                    \(Int(progress * 100))% complete
                    Time remaining: \(formatTime(remaining))
                    """
            } else {
                progressLabel.text = "Starting export..."
            }
            
            progressView.progress = progress
        }
    }
    
    try await exporter.export(
        asset: sourceAsset,
        video: .codec(.h264, width: 1920, height: 1080),
        to: destinationURL,
        as: .mp4
    )
}

private func formatTime(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    let seconds = Int(seconds) % 60
    return String(format: "%d:%02d", minutes, seconds)
}
```

## See Also

- ``ExportSession`` - Main export class with progress stream
- <doc:ErrorHandling> - Handling errors during progress tracking
- <doc:PerformanceOptimization> - Optimizing export performance
- <doc:GettingStarted> - Basic usage examples