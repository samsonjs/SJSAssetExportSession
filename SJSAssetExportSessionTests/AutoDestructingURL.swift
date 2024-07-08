//
//  AutoDestructingURL.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2024-07-07.
//

import Foundation
import OSLog

private let log = Logger(OSLog(subsystem: "SJSAssetExportSessionTests", category: "AutoDestructingURL"))

/// Wraps a URL and deletes it when this instance is deallocated. Failures to delete the file are logged.
final class AutoDestructingURL: Hashable, Sendable {
    let url: URL

    init(url: URL) {
        precondition(url.isFileURL, "AutoDestructFile only works with local file URLs")
        self.url = url
    }

    deinit {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }

        do {
            try fm.removeItem(at: url)
            log.debug("Auto-destructed \(self.url)")
        } catch {
            log.error("Failed to auto-destruct \(self.url): \(error)")
        }
    }

    static func == (lhs: AutoDestructingURL, rhs: AutoDestructingURL) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
