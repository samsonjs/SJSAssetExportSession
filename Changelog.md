# Changelog

## [Unreleased]

- Your change here.

[Unreleased]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.3.9...HEAD

## [0.3.9] - 2025-05-25

### Fixed
- Fixed crash on iOS 17 by using a new task instead of assumeIsolated

[0.3.9]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.3.8...0.3.9

## [0.3.8] - 2025-04-04

### Fixed
- Fixed crash when cancelled while writing samples
- Fixed tests with Swift 6.1 on macOS
- Fixed tests in Xcode 16.4 on macOS 15.5
- Fixed warnings in tests in Xcode 16.3

### Changed
- Stopped relying on specific delay in cancellation test
- Updated readme for 0.3.8

[0.3.8]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.3.7...0.3.8

## [0.3.7] - 2025-01-19

### Fixed
- Simplified cancellation and fixed memory leak

[0.3.7]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.3.6...0.3.7

## [0.3.6] - 2025-01-19

### Fixed
- Attempted to fix possible retain cycle

[0.3.6]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.3.5...0.3.6

## [0.3.5] - 2025-01-19

### Fixed
- Improved cancellation response (potential memory leak issue)

### Removed
- Deleted dead code

### Changed
- Extracted BaseTests class for better test organization

[0.3.5]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.3.4...0.3.5

## [0.3.4] - 2024-11-08

### Fixed
- [#3](https://github.com/samsonjs/SJSAssetExportSession/pull/3): Fixed encoding stalling by interleaving audio and video samples - [@samsonjs](https://github.com/samsonjs).

### Changed
- Updated readme with additional documentation

[0.3.4]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.3.3...0.3.4

## [0.3.3] - 2024-10-19

### Changed
- Made AudioOutputSettings and VideoOutputSettings properties public

### Fixed
- Made tests work on iOS 18.0 and iOS 18.1
- Fixed progress test

### Removed
- Removed SampleWriter.duration property

[0.3.3]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.3.2...0.3.3

## [0.3.2] - 2024-10-19

### Fixed
- Fixed release builds by using makeStream for SampleWriter's progress

### Changed
- Updated example in readme to version 0.3.2

[0.3.2]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.3.1...0.3.2

## [0.3.1] - 2024-10-19

### Fixed
- Removed unnecessary Task.yield() to fix intermittent hang

### Changed
- Improved code style and debuggability
- Updated version in readme to 0.3.1

[0.3.1]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.3...0.3.1

## [0.3] - 2024-10-18

### Added
- Made audio/video settings Hashable, Sendable, and Codable

### Changed
- Updated readme for version 0.3
- Fixed SwiftPM instructions in readme

[0.3]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.2...0.3

## [0.2] - 2024-10-04

### Fixed
- [#2](https://github.com/samsonjs/SJSAssetExportSession/pull/2): Fixed spatial audio handling by dropping spatial audio tracks to fix encoding iPhone 16 videos - [@samsonjs](https://github.com/samsonjs).

### Changed
- Code style improvements
- Updated version in readme's SPM example

[0.2]: https://github.com/samsonjs/SJSAssetExportSession/compare/0.1...0.2

## [0.1] - 2024-09-18

### Added
- Initial release as Swift Package
- Alternative to AVAssetExportSession with custom audio/video settings
- Builder pattern API for AudioOutputSettings and VideoOutputSettings
- Flexible raw dictionary API for maximum control
- Progress reporting via AsyncStream
- Support for iOS 17.0+, macOS 14.0+, and visionOS 1.3+
- Swift 6 strict concurrency support
- Comprehensive test suite with multiple video formats

### Changed
- Converted from Xcode project to Swift package
- Made yielding last progress value more reliable
- Set deployment targets to iOS 17, macOS 14, and visionOS 1.3

### Added
- Support for writing metadata on assets
- Documentation for most public API
- README and license files

[0.1]: https://github.com/samsonjs/SJSAssetExportSession/releases/tag/0.1
