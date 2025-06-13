//
//  Array+Extensions.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2024-10-04.
//

extension Array {
    /// Filters the array using an async predicate function.
    ///
    /// - Parameter isIncluded: Async predicate to test each element.
    /// - Returns: Array containing only elements where the predicate returned true.
    func filterAsync(_ isIncluded: (Element) async throws -> Bool) async rethrows -> [Element] {
        var result: [Element] = []
        for element in self {
            if try await isIncluded(element) {
                result.append(element)
            }
        }
        return result
    }
}
