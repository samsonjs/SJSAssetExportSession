# Performance Optimization

Learn how to optimize export performance and handle large video files efficiently.

## Overview

Export performance depends on many factors including source file characteristics, output settings, device capabilities, and system resources. This guide covers strategies to optimize export speed while maintaining quality.

## Understanding Performance Factors

### Key Performance Variables

1. **Source Resolution**: Higher resolution sources require more processing
2. **Output Resolution**: Scaling affects performance
3. **Codec Choice**: H.264 vs HEVC vs other codecs
4. **Bitrate**: Higher bitrates require more processing
5. **Frame Rate**: Higher frame rates increase workload
6. **Device Capabilities**: CPU, GPU, and available memory

### Performance vs Quality Trade-offs

```swift
// Fast export (lower quality)
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.baseline30), width: 1280, height: 720)
        .fps(24)
        .bitrate(1_500_000),
    to: destinationURL,
    as: .mp4
)

// Balanced export
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.main32), width: 1920, height: 1080)
        .fps(30)
        .bitrate(4_000_000),
    to: destinationURL,
    as: .mp4
)

// High quality (slower)
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.hevc, width: 3840, height: 2160)
        .fps(60)
        .bitrate(20_000_000),
    to: destinationURL,
    as: .mov
)
```

## Codec Optimization

### H.264 Profile Selection

Choose the appropriate H.264 profile for your performance needs:

```swift
// Fastest encoding - Baseline profile
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.baselineAuto), width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)

// Balanced - Main profile
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.mainAuto), width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)

// Best compression (slower) - High profile
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264(.highAuto), width: 1920, height: 1080),
    to: destinationURL,
    as: .mp4
)
```

### HEVC Considerations

HEVC provides better compression but requires more processing power:

```swift
// Use HEVC only when:
// 1. Target devices support it
// 2. File size is more important than encoding speed
// 3. You have sufficient processing power

try await exporter.export(
    asset: sourceAsset,
    video: .codec(.hevc, width: 1920, height: 1080)
        .bitrate(3_000_000), // Lower bitrate than H.264 for same quality
    to: destinationURL,
    as: .mp4
)
```

## Resolution and Scaling Optimization

### Intelligent Resolution Selection

```swift
func optimizedResolution(for sourceAsset: AVAsset) async throws -> CGSize {
    let videoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
    guard let firstTrack = videoTracks.first else {
        throw ExportSession.Error.setupFailure(.videoTracksEmpty)
    }
    
    let naturalSize = try await firstTrack.load(.naturalSize)
    
    // Don't upscale - only downscale for performance
    if naturalSize.width <= 1280 && naturalSize.height <= 720 {
        return naturalSize
    } else if naturalSize.width <= 1920 && naturalSize.height <= 1080 {
        return CGSize(width: 1280, height: 720) // Downscale to 720p
    } else {
        return CGSize(width: 1920, height: 1080) // Downscale to 1080p
    }
}

// Usage
let optimalSize = try await optimizedResolution(for: sourceAsset)
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, size: optimalSize),
    to: destinationURL,
    as: .mp4
)
```

### Avoiding Unnecessary Scaling

```swift
// Check if scaling is needed
func needsScaling(sourceSize: CGSize, targetSize: CGSize) -> Bool {
    return sourceSize.width != targetSize.width || sourceSize.height != targetSize.height
}

// Match source resolution when possible
let videoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
if let track = videoTracks.first {
    let naturalSize = try await track.load(.naturalSize)
    
    try await exporter.export(
        asset: sourceAsset,
        video: .codec(.h264, size: naturalSize), // No scaling needed
        to: destinationURL,
        as: .mp4
    )
}
```

## Frame Rate Optimization

### Source-Based Frame Rate Selection

```swift
func optimizedFrameRate(for asset: AVAsset) async throws -> Int? {
    let videoTracks = try await asset.loadTracks(withMediaType: .video)
    guard let track = videoTracks.first else { return nil }
    
    let nominalFrameRate = try await track.load(.nominalFrameRate)
    
    // Use source frame rate or a common divisor
    switch nominalFrameRate {
    case 0..<25:
        return 24
    case 25..<30:
        return 25
    case 30..<50:
        return 30
    case 50..<60:
        return 50
    default:
        return 60
    }
}

// Usage
let optimalFPS = try await optimizedFrameRate(for: sourceAsset)

try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080)
        .fps(optimalFPS ?? 30),
    to: destinationURL,
    as: .mp4
)
```

## Memory Management

### Handling Large Files

```swift
func exportLargeFile(asset: AVAsset) async throws {
    // Check available memory
    let processInfo = ProcessInfo.processInfo
    let physicalMemory = processInfo.physicalMemory
    
    // Adjust settings based on available memory
    let videoSettings: VideoOutputSettings
    if physicalMemory < 4_000_000_000 { // Less than 4GB
        videoSettings = .codec(.h264(.baseline31), width: 1280, height: 720)
            .fps(24)
            .bitrate(2_000_000)
    } else if physicalMemory < 8_000_000_000 { // Less than 8GB
        videoSettings = .codec(.h264(.main32), width: 1920, height: 1080)
            .fps(30)
            .bitrate(4_000_000)
    } else {
        videoSettings = .codec(.h264(.high40), width: 1920, height: 1080)
            .fps(30)
            .bitrate(6_000_000)
    }
    
    try await exporter.export(
        asset: asset,
        video: videoSettings,
        to: destinationURL,
        as: .mp4
    )
}
```

### Memory-Efficient Settings

```swift
// Use raw settings for fine-grained memory control
let memoryEfficientVideoSettings: [String: any Sendable] = [
    AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
    AVVideoWidthKey: NSNumber(value: 1280),
    AVVideoHeightKey: NSNumber(value: 720),
    AVVideoCompressionPropertiesKey: [
        AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
        AVVideoAverageBitRateKey: NSNumber(value: 2_000_000),
        AVVideoMaxKeyFrameIntervalKey: NSNumber(value: 30),
        AVVideoAllowFrameReorderingKey: NSNumber(value: false), // Reduces memory usage
        AVVideoExpectedSourceFrameRateKey: NSNumber(value: 24)
    ] as [String: any Sendable]
]

try await exporter.export(
    asset: sourceAsset,
    audioOutputSettings: AudioOutputSettings.default.settingsDictionary,
    videoOutputSettings: memoryEfficientVideoSettings,
    to: destinationURL,
    as: .mp4
)
```

## Parallel Processing

### Batch Export Optimization

```swift
class OptimizedBatchExporter {
    private let maxConcurrentExports: Int
    
    init(maxConcurrentExports: Int = 2) {
        // Limit concurrent exports based on system capabilities
        let processorCount = ProcessInfo.processInfo.processorCount
        self.maxConcurrentExports = min(maxConcurrentExports, max(1, processorCount / 2))
    }
    
    func exportFiles(_ files: [(asset: AVAsset, url: URL)]) async throws {
        // Process files in chunks to avoid overwhelming the system
        for chunk in files.chunked(into: maxConcurrentExports) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for file in chunk {
                    group.addTask {
                        let exporter = ExportSession()
                        try await exporter.export(
                            asset: file.asset,
                            video: .codec(.h264, width: 1280, height: 720),
                            to: file.url,
                            as: .mp4
                        )
                    }
                }
                
                try await group.waitForAll()
            }
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<min($0 + size, count)])
        }
    }
}
```

## Device-Specific Optimization

### iOS Device Capabilities

```swift
import UIKit

func deviceOptimizedSettings() -> VideoOutputSettings {
    let device = UIDevice.current
    
    // Check device capabilities
    if device.userInterfaceIdiom == .pad {
        // iPad - more processing power
        return .codec(.h264(.high40), width: 1920, height: 1080)
            .fps(30)
            .bitrate(5_000_000)
    } else {
        // iPhone - optimize for battery and heat
        return .codec(.h264(.main32), width: 1280, height: 720)
            .fps(30)
            .bitrate(3_000_000)
    }
}
```

### macOS Optimization

```swift
#if os(macOS)
import IOKit

func macOptimizedSettings() -> VideoOutputSettings {
    // Check for discrete GPU
    let hasDiscreteGPU = hasDiscreteGraphics()
    
    if hasDiscreteGPU {
        // Use higher settings with discrete GPU
        return .codec(.hevc, width: 3840, height: 2160)
            .fps(30)
            .bitrate(15_000_000)
    } else {
        // Conservative settings for integrated graphics
        return .codec(.h264(.main32), width: 1920, height: 1080)
            .fps(30)
            .bitrate(4_000_000)
    }
}

private func hasDiscreteGraphics() -> Bool {
    // Implementation to check for discrete GPU
    // This is a simplified check - actual implementation would be more complex
    return false
}
#endif
```

## Monitoring and Profiling

### Performance Metrics

```swift
class PerformanceMonitor {
    private var startTime: Date?
    private var startMemory: UInt64?
    
    func startMonitoring() {
        startTime = Date()
        startMemory = getCurrentMemoryUsage()
    }
    
    func endMonitoring(fileSize: UInt64) -> PerformanceReport {
        let endTime = Date()
        let endMemory = getCurrentMemoryUsage()
        
        let duration = endTime.timeIntervalSince(startTime ?? endTime)
        let memoryDelta = endMemory - (startMemory ?? 0)
        let processingSpeed = Double(fileSize) / duration // bytes per second
        
        return PerformanceReport(
            duration: duration,
            memoryUsed: memoryDelta,
            processingSpeed: processingSpeed
        )
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}

struct PerformanceReport {
    let duration: TimeInterval
    let memoryUsed: UInt64
    let processingSpeed: Double // bytes per second
    
    var mbPerSecond: Double {
        return processingSpeed / 1_000_000
    }
}
```

### Usage Example

```swift
func monitoredExport() async throws {
    let monitor = PerformanceMonitor()
    monitor.startMonitoring()
    
    let exporter = ExportSession()
    try await exporter.export(
        asset: sourceAsset,
        video: .codec(.h264, width: 1920, height: 1080),
        to: destinationURL,
        as: .mp4
    )
    
    let fileSize = try FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? UInt64 ?? 0
    let report = monitor.endMonitoring(fileSize: fileSize)
    
    print("Export completed in \(report.duration)s")
    print("Processing speed: \(report.mbPerSecond) MB/s")
    print("Memory used: \(report.memoryUsed / 1_000_000) MB")
}
```

## Common Performance Issues

### Avoiding Common Pitfalls

1. **Don't upscale unnecessarily**:
```swift
// Bad: Upscaling from 720p to 4K
try await exporter.export(
    asset: sourceAsset720p,
    video: .codec(.h264, width: 3840, height: 2160), // Unnecessary upscaling
    to: destinationURL,
    as: .mp4
)

// Good: Maintain source resolution
try await exporter.export(
    asset: sourceAsset720p,
    video: .codec(.h264, width: 1280, height: 720),
    to: destinationURL,
    as: .mp4
)
```

2. **Choose appropriate bitrates**:
```swift
// Bad: Excessive bitrate for resolution
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1280, height: 720)
        .bitrate(20_000_000), // Too high for 720p
    to: destinationURL,
    as: .mp4
)

// Good: Appropriate bitrate
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1280, height: 720)
        .bitrate(2_500_000), // Suitable for 720p
    to: destinationURL,
    as: .mp4
)
```

3. **Consider frame rate needs**:
```swift
// Bad: Unnecessary high frame rate
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080)
        .fps(120), // Overkill for most content
    to: destinationURL,
    as: .mp4
)

// Good: Standard frame rate
try await exporter.export(
    asset: sourceAsset,
    video: .codec(.h264, width: 1920, height: 1080)
        .fps(30), // Standard and efficient
    to: destinationURL,
    as: .mp4
)
```

## Adaptive Quality Selection

### Dynamic Settings Based on Source

```swift
func adaptiveExportSettings(for asset: AVAsset) async throws -> VideoOutputSettings {
    let videoTracks = try await asset.loadTracks(withMediaType: .video)
    guard let track = videoTracks.first else {
        throw ExportSession.Error.setupFailure(.videoTracksEmpty)
    }
    
    let naturalSize = try await track.load(.naturalSize)
    let nominalFrameRate = try await track.load(.nominalFrameRate)
    let estimatedDataRate = try await track.load(.estimatedDataRate)
    
    // Calculate appropriate output settings
    let outputWidth = min(Int(naturalSize.width), 1920)
    let outputHeight = min(Int(naturalSize.height), 1080)
    let outputFPS = min(Int(nominalFrameRate), 30)
    let outputBitrate = min(Int(estimatedDataRate), 5_000_000)
    
    return .codec(.h264(.mainAuto), width: outputWidth, height: outputHeight)
        .fps(outputFPS)
        .bitrate(outputBitrate)
}

// Usage
let settings = try await adaptiveExportSettings(for: sourceAsset)
try await exporter.export(
    asset: sourceAsset,
    video: settings,
    to: destinationURL,
    as: .mp4
)
```

## Testing Performance

### Benchmarking Different Settings

```swift
func benchmarkSettings() async throws {
    let testCases: [(name: String, settings: VideoOutputSettings)] = [
        ("Fast", .codec(.h264(.baseline30), width: 1280, height: 720).fps(24).bitrate(1_500_000)),
        ("Balanced", .codec(.h264(.main32), width: 1920, height: 1080).fps(30).bitrate(4_000_000)),
        ("Quality", .codec(.h264(.high40), width: 1920, height: 1080).fps(30).bitrate(8_000_000)),
        ("HEVC", .codec(.hevc, width: 1920, height: 1080).fps(30).bitrate(3_000_000))
    ]
    
    for testCase in testCases {
        let startTime = Date()
        
        let exporter = ExportSession()
        try await exporter.export(
            asset: sourceAsset,
            video: testCase.settings,
            to: URL.temporaryDirectory.appending(component: "\(testCase.name).mp4"),
            as: .mp4
        )
        
        let duration = Date().timeIntervalSince(startTime)
        print("\(testCase.name): \(duration)s")
    }
}
```

## See Also

- <doc:VideoConfiguration> - Video settings options
- <doc:AudioConfiguration> - Audio settings optimization
- <doc:ProgressTracking> - Monitoring export progress
- <doc:ErrorHandling> - Handling performance-related errors