//
//  CMTime+seconds.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-07.
//

public import CoreMedia

public extension CMTime {
    /// Creates a CMTime with the specified duration in seconds using a timescale of 600.
    ///
    /// The timescale of 600 provides good precision for typical video frame rates.
    ///
    /// - Parameter seconds: The duration in seconds.
    /// - Returns: A CMTime representing the specified duration.
    static func seconds(_ seconds: TimeInterval) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: 600)
    }
}
