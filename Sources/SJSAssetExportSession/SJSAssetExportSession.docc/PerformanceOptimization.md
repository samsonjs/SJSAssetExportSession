# Performance Optimization

Practical tips for faster exports and efficient resource usage.

## Codec Selection

**Fastest to slowest:**
1. H.264 Baseline - Fast encoding, larger files
2. H.264 Main - Balanced (recommended default)
3. H.264 High - Better compression, slower
4. HEVC - Best compression, slowest

```swift
// Fast export
.codec(.h264(.baseline30), width: 1280, height: 720)

// Balanced
.codec(.h264(.main32), width: 1920, height: 1080)

// High compression
.codec(.hevc, width: 1920, height: 1080)
```

## Resolution Guidelines

- **Don't upscale** - Export at source resolution or smaller
- **Use standard resolutions** - 720p, 1080p, 4K
- **Consider device targets** - Mobile apps rarely need 4K

```swift
// Get source resolution first
let tracks = try await asset.loadTracks(withMediaType: .video)
let naturalSize = try await tracks.first?.load(.naturalSize)

// Export at source resolution or smaller
.codec(.h264, width: min(1920, naturalSize.width), height: min(1080, naturalSize.height))
```

## Frame Rate

Match or reduce source frame rate:

```swift
let sourceFrameRate = try await videoTrack.load(.nominalFrameRate)

// Don't increase frame rate
.fps(min(30, Int(sourceFrameRate)))
```

## Memory Management

For large files, reduce concurrent operations and use lower settings:

```swift
// For 4K+ sources, consider reducing output resolution
if sourceWidth > 3840 {
    .codec(.h264(.main32), width: 1920, height: 1080)
} else {
    .codec(.h264(.main32), width: sourceWidth, height: sourceHeight)
}
```

## Common Pitfalls

**Avoid:**
- Upscaling resolution (1080p → 4K)
- Increasing frame rate (24fps → 60fps)
- Using HEVC for time-critical exports
- Extremely high bitrates (>50Mbps for most use cases)

**Do:**
- Test with representative content
- Monitor memory usage with large files
- Use network optimization for streaming: `optimizeForNetworkUse: true`

## See Also

- <doc:VideoConfiguration> - Video settings reference