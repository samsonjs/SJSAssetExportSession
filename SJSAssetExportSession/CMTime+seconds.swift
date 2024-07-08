//
//  CMTime+seconds.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-07-07.
//

public import CoreMedia

public extension CMTime {
    static func seconds(_ seconds: TimeInterval) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: 600)
    }
}
