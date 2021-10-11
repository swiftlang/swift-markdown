/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension RangeReplaceableCollection {
    /// Append filler elements until ``count`` is at least `minCount`.
    mutating func ensureCount(atLeast minCount: Int, filler: Element) {
        let neededElementCount = minCount - count
        if neededElementCount > 0 {
            self.append(contentsOf: Array(repeating: filler, count: neededElementCount))
        }
    }

    /// Return a copy of `self` with filler elements appended until ``count`` is at least `minCount`.
    func ensuringCount(atLeast minCount: Int, filler: Element) -> Self {
        var maybeExtend = self
        maybeExtend.ensureCount(atLeast: minCount, filler: filler)
        return maybeExtend
    }
}
