//
//  SendableWrapper.swift
//  SJSAssetExportSessionTests
//
//  Created by Sami Samhuri on 2024-07-07.
//

import Foundation

final class SendableWrapper<T>: @unchecked Sendable {
    private var unsafeValue: T

    private let lock = NSLock()

    var value: T {
        get {
            lock.withLock { unsafeValue }
        }
        set {
            lock.withLock { unsafeValue = newValue }
        }
    }

    init(_ value: T) {
        unsafeValue = value
    }
}
