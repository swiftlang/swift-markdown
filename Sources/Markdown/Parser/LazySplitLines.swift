/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A lazy sequence of split lines that keeps track of initial indentation and
/// consecutive runs of empty lines.
struct LazySplitLines: Sequence {
    struct Iterator: IteratorProtocol {
        /// The current running count of consecutive empty lines before the current iteration.
        private var precedingConsecutiveEmptyLineCount = 0

        /// The raw lines to be iterated.
        private let rawLines: [Substring]

        /// The current index of the iteration.
        private var index: Array<Substring>.Index

        /// The source file or resource from which the line came,
        /// or `nil` if no such file or resource can be identified.
        private var source: URL?

        init<S: StringProtocol>(_ input: S, source: URL?) where S.SubSequence == Substring {
            self.rawLines = input.split(separator: "\n", maxSplits: Int.max, omittingEmptySubsequences: false)
            self.index = rawLines.startIndex
            self.source = source
        }

        mutating func next() -> TrimmedLine? {
            guard index != rawLines.endIndex else {
                return nil
            }

            let segment = TrimmedLine(rawLines[index], source: source, lineNumber: index + 1)

            index = rawLines.index(after: index)

            if segment.text.isEmpty {
                precedingConsecutiveEmptyLineCount += 1
            } else {
                precedingConsecutiveEmptyLineCount = 0
            }

            return segment
        }
    }

    /// The input to be lazily split on newlines.
    private let input: Substring

    /// The source file or resource from which the line came,
    /// or `nil` if no such file or resource can be identified.
    private let source: URL?

    init(_ input: Substring, source: URL?) {
        self.input = input
        self.source = source
    }

    func makeIterator() -> Iterator {
        return Iterator(input, source: source)
    }
}

