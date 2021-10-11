/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A structure to automate incrementing child identifiers while
/// adding their source ranges during parsing.
struct RangeTracker {
    /// The narrowest range that covers all ranges seen so far.
    private(set) var totalRange: SourceRange

    /// Create a range tracker with a starting total range.
    ///
    /// - parameter totalRange: the narrowest range that covers all ranges seen so far.
    init(totalRange: SourceRange) {
        self.totalRange = totalRange
    }

    /// Add a source range and increment the next child identifier.
    ///
    /// - parameter range: An optional ``SourceRange``. This may be `nil` for
    ///   some elements for which cmark doesn't track a range, such as
    ///   soft breaks.
    mutating func add(_ range: SourceRange?) {
        if let range = range {
            totalRange.widen(toFit: range)
        }
    }
}
