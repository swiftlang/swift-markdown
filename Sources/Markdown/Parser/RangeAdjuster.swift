/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A type for adjusting the columns of elements that are parsed in *line runs*
/// of the block directive parser to their locations before their indentation was trimmed.
struct RangeAdjuster: MarkupWalker {
    /// The line number of the first line in the line run that needs adjustment.
    var startLine: Int

    /// The tracker that will collect the adjusted ranges.
    var ranges: RangeTracker

    /// An array of whitespace spans that were removed for each line, indexed
    /// by line number. `nil` means that no whitespace was removed on that line.
    var trimmedIndentationPerLine: [Int]

    mutating func defaultVisit(_ markup: Markup) {
        /// This should only be used in the parser where ranges are guaranteed
        /// to be filled in from cmark.
        let adjustedRange = markup.range.map { range -> SourceRange in
            // Add back the offset to the column as if the indentation weren't stripped.
            func indentation(for cmarkLine: Int) -> Int {
                let index = cmarkLine - 1
                guard !trimmedIndentationPerLine.isEmpty else { return 0 }
                // Clamp index to valid range
                let safeIndex = min(max(0, index), trimmedIndentationPerLine.count - 1)
                return trimmedIndentationPerLine[safeIndex]
            }

            let start = SourceLocation(line: startLine + range.lowerBound.line - 1,
                                       column: range.lowerBound.column + indentation(for: range.lowerBound.line),
                                       source: range.lowerBound.source)
            let end = SourceLocation(line: startLine + range.upperBound.line - 1,
                                     column: range.upperBound.column + indentation(for: range.upperBound.line),
                                     source: range.upperBound.source)
            return start..<end
        }
        ranges.add(adjustedRange)

        // Warning! Unsafe stuff!
        // Unsafe mutation of shared reference types.
        // This should only ever be called during parsing.

        markup.raw.markup.header.parsedRange = adjustedRange

        for child in markup.children {
            child.accept(&self)
        }

        // End unsafe stuff.
    }
}

