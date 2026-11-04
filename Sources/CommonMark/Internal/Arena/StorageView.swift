/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A lightweight, copyable view over a `DocumentStorage`'s heap-backed buffers plus the borrowed source bytes.
///
/// `~Escapable, Copyable` - the same shape as `Span<T>`. Used as the carrier in `MarkdownNode` and `Children` so each accessor reaches into stable heap memory (for storage-owned buffers) or the borrowed source (`Span<UInt8>`) without re-extracting pointers.
///
/// Construction is tied to both the storage's borrow scope and the source's lifetime.
internal struct StorageView: ~Escapable, Copyable {
    internal let nodes: Span<NodeRecord>
    internal let strings: Span<UInt8>
    internal let segments: Span<Segment>
    internal let tableAlignments: Span<MarkdownNode.TableAlignment>
    internal let lineStarts: Span<Int>
    internal let sourceRanges: Span<DocumentStorage.SourceByteRange>
    internal let source: Span<UInt8>
    internal let options: MarkdownDocument.ParseOptions

    @_lifetime(borrow storage, copy source)
    internal init(storage: borrowing DocumentStorage, source: Span<UInt8>) {
        self.nodes = storage.nodes.span
        self.strings = storage.strings.span
        self.segments = storage.segments.span
        self.tableAlignments = storage.tableAlignments.span
        self.lineStarts = storage.lineStarts.span
        self.sourceRanges = storage.sourceRanges.span
        self.source = source
        self.options = storage.options
    }

    /// Convert a source byte offset to a 1-based (line, column) position.
    ///
    /// `column` is the 1-based UTF-8 byte offset within the line (matching cmark). Requires a populated `lineStarts`.
    internal func position(ofByte offset: Int) -> MarkdownNode.SourcePosition {
        // Largest line index `i` with lineStarts[i] <= offset (binary search; lineStarts is ascending).
        var lo = 0
        var hi = lineStarts.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if lineStarts[mid] <= offset {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        let lineIndex = max(0, lo - 1)
        let lineStart = lineStarts.count > 0 ? lineStarts[lineIndex] : 0
        return MarkdownNode.SourcePosition(line: lineIndex + 1, column: Int(offset - lineStart) + 1)
    }

    /// The 1-based source position range for a node, or `nil` if positions are off or the node was never stamped.
    ///
    /// `end` points just past the node's last content byte (half-open), converted as the position of that last byte... see `MarkdownNode.sourceRange` for the exposed convention.
    internal func sourceRange(of index: DocumentStorage.Index) -> Range<MarkdownNode.SourcePosition>? {
        guard sourceRanges.count > index else { return nil }
        let r = sourceRanges[index]
        guard r.start >= 0, r.end >= 0 else { return nil }
        let start = position(ofByte: r.start)
        let end = position(ofByte: r.end)
        guard start <= end else { return nil }
        return start..<end
    }

    /// Read a node record by index.
    internal func record(at index: DocumentStorage.Index) -> NodeRecord {
        nodes[index]
    }

    // MARK: - Content bytes (always available)

    @_lifetime(borrow self)
    internal func bytes(of segment: Segment) -> Span<UInt8> {
        bytes(of: segment.chunk)
    }

    /// Resolve a single-segment `ContentRef` to a borrowed byte span.
    ///
    /// Empty content yields an empty span. For multi-segment content (count > 1) this returns only the first segment - callers that can see multi-segment content (code/HTML block bodies) must iterate the segments instead.
    @_lifetime(borrow self)
    internal func bytes(of ref: ContentRef) -> Span<UInt8> {
        if ref.count == 0 {
            return strings.extracting(0..<0)
        }
        return bytes(of: segments[Int(ref.first)])
    }

    @_lifetime(borrow self)
    internal func bytes(of chunk: Chunk) -> Span<UInt8> {
        let start = Int(chunk.offset)
        let length = Int(chunk.length)
        if chunk.inSource {
            return source.extracting(start..<(start + length))
        } else {
            return strings.extracting(start..<(start + length))
        }
    }

    // MARK: - Content as String (always available)
    
    /// Concatenate a (possibly multi-segment) `ContentRef` into one `String`.
    internal func string(of ref: ContentRef) -> String {
        if ref.count == 0 {
            return ""
        } else if ref.count == 1 {
            let span = bytes(of: segments[Int(ref.first)].chunk)
            if #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) {
                let utf8 = UTF8Span(unchecked: span)
                return String(copying: utf8)
            } else {
                return String(unsafeUninitializedCapacity: span.count) { buffer in
                    var output = OutputSpan(buffer: buffer, initializedCount: 0)
                    for b in 0..<span.count {
                        output.append(span[b])
                    }
                    return output.count
                }
            }
        } else {
            return String(unsafeUninitializedCapacity: Int(ref.totalLength)) { buffer in
                var output = OutputSpan(buffer: buffer, initializedCount: 0)
                for i in 0..<Int(ref.count) {
                    let span = bytes(of: segments[Int(ref.first) + i].chunk)
                    for b in 0..<span.count {
                        output.append(span[b])
                    }
                }
                return output.count
            }
        }
    }

    // MARK: - Content as UTF8Span (anyAppleOS 26 only)

    /// Returns a `UTF8Span` from the raw byte span for the `UTF8Span`-vending public content API.
    ///
    /// Source-derived chunks are always cut on scalar boundaries (the parser only ever splits on ASCII delimiters/whitespace/newlines), so validation succeeds for well-formed input.
    @available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
    @_lifetime(borrow self)
    internal func utf8Span(of segment: Segment) -> UTF8Span {
        utf8Span(of: segment.chunk)
    }

    /// Returns a `UTF8Span` from the raw byte span for the `UTF8Span`-vending public content API.
    ///
    /// Source-derived chunks are always cut on scalar boundaries (the parser only ever splits on ASCII delimiters/whitespace/newlines), so validation succeeds for well-formed input.
    @available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
    @_lifetime(borrow self)
    internal func utf8Span(of ref: ContentRef) -> UTF8Span {
        if ref.count == 0 {
            return unsafe UTF8Span(unchecked: strings.extracting(0..<0))
        }
        return utf8Span(of: segments[Int(ref.first)])
    }

    @available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
    @_lifetime(borrow self)
    internal func utf8Span(of chunk: Chunk) -> UTF8Span {
        // Content bytes are already known-valid UTF-8 (source-derived from validated input, or valid arena bytes) and cut on scalar boundaries, so skip re-validation.
        unsafe UTF8Span(unchecked: bytes(of: chunk))
    }
}
