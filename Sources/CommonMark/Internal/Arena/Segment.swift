/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// One piece of a node's content: a byte range that lives in either the borrowed source `Span` (`inSource == true`) or `DocumentStorage`'s additions arena (`inSource == false`).
///
/// A `Segment` is the N-way generalization of `Chunk`'s `inSource` two-buffer scheme. Nodes reference an ordered run of these (see `ContentRef`) so that content spanning multiple source ranges (a multi-line paragraph) or mixing source with synthetic bytes (a joined newline, a decoded entity) can be represented without copying the source bytes into an intermediate buffer.
///
/// `Int32` fields keep the per-document segment pool compact; markdown sources are far below the 2 GiB limit this implies.
internal struct Segment: Equatable {
    internal var offset: Int32
    internal var length: Int32
    internal var inSource: Bool

    internal init(offset: Int32, length: Int32, inSource: Bool) {
        self.offset = offset
        self.length = length
        self.inSource = inSource
    }

    internal init(_ chunk: Chunk) {
        self.offset = Int32(chunk.offset)
        self.length = Int32(chunk.length)
        self.inSource = chunk.inSource
    }

    /// Reconstruct a `Chunk` view of this segment. Used by internal parser code that still works in the single-buffer `Chunk` vocabulary.
    internal var chunk: Chunk {
        Chunk(offset: Int(offset), length: Int(length), inSource: inSource)
    }
}

/// A node's content, expressed as a contiguous slice `[first, first + count)` of `DocumentStorage.segments`.
///
/// The overwhelmingly common case is `count == 1` (a single source range - most text runs, URLs, and labels), which costs the same as a single inline `Chunk`. `totalLength` caches the total byte length across the segments so length queries don't have to walk the pool.
internal struct ContentRef: Equatable {
    internal var first: Int32
    internal var count: Int32
    internal var totalLength: Int32

    internal init(first: Int32, count: Int32, totalLength: Int32) {
        self.first = first
        self.count = count
        self.totalLength = totalLength
    }

    internal static let empty = ContentRef(first: 0, count: 0, totalLength: 0)
}
