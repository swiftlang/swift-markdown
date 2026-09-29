/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A read-only view over a single block's inline content, resolved once before inline parsing begins.
///
/// Two modes, distinguished by `isMultiSegment`:
///
/// - **Single-segment (the overwhelmingly common case).** The content is one contiguous buffer region - a zero-copy slice of the source (`inSource == true`) or of a scratch copy of `storage.strings` (`inSource == false`). Bytes are addressed by *global* offsets (`startOffset..<endOffset`) via a branchless `span[offset - base]`, identical in cost to a plain single-buffer read. For source-backed content the global offset IS the original-source byte offset.
///
/// - **Multi-segment.** The content is an ordered list of `Segment`s - source-line ranges (zero-copy into `sourceBytes`) joined by the shared interned `"\n"` - addressed by flat *virtual* offsets (`0..<virtualLength`). Used for multi-line paragraph/heading bodies whose lines aren't source-contiguous (block-quote/list continuation, CRLF) so no source bytes are copied. The input never contains arena-only bytes (decoded entities / synthesized runs are produced *during* inline parsing, not present in the raw block content), so reads come only from `sourceBytes` plus the literal `\n` - `storage.strings` is never held across the inline loop's appends.
///
/// `sourceOffset(ofVirtual:)` maps a (virtual) offset back to its original-source byte offset (or `nil` for arena/synthetic positions), which is how inline nodes get stamped with source ranges.
internal struct ContentSpan: ~Escapable {
    /// Single-segment: the content bytes (0-based via `base`). Multi-segment: `sourceBytes` (the whole source), indexed directly by a segment's absolute source offset.
    @usableFromInline let span: Span<UInt8>

    /// Single-segment: the global offset of `span[0]` (subtracted from a global offset to index `span`). Multi-segment: unused (0).
    @usableFromInline let base: Int

    /// Single-segment: which buffer `span` is (`true` = source, `false` = arena scratch). Multi-segment: unused.
    @usableFromInline let inSource: Bool

    /// Multi-segment only: the content's segments (empty for single-segment). A copy held in stable storage for the inline loop's duration (the live `storage.segments` pool grows during parsing).
    @usableFromInline let segments: Span<Segment>

    /// Multi-segment only: total virtual byte length across `segments`.
    @usableFromInline let multiVirtualLength: Int

    /// Single-segment initializer (zero-copy source slice or arena scratch).
    @_lifetime(copy span)
    @inlinable
    init(span: Span<UInt8>, base: Int, inSource: Bool) {
        self.span = span
        self.base = base
        self.inSource = inSource
        self.segments = Span<Segment>()
        self.multiVirtualLength = 0
    }

    /// Multi-segment initializer: `source` is the borrowed source bytes; `segments` is the content's segment list (held in stable storage); `virtualLength` is their total length.
    @_lifetime(copy source, copy segments)
    @inlinable
    init(source: Span<UInt8>, segments: Span<Segment>, virtualLength: Int) {
        self.span = source
        self.base = 0
        self.inSource = false
        self.segments = segments
        self.multiVirtualLength = virtualLength
    }

    @inlinable
    var isMultiSegment: Bool { segments.count > 0 }

    /// Global/virtual offset of the first content byte.
    @inlinable
    var startOffset: Int { isMultiSegment ? 0 : base }

    /// Global/virtual offset just past the last content byte.
    @inlinable
    var endOffset: Int { isMultiSegment ? multiVirtualLength : base + span.count }

    @inlinable
    var isEmpty: Bool { isMultiSegment ? multiVirtualLength == 0 : span.count == 0 }

    /// Read the byte at `offset` (global for single-segment, virtual for multi-segment).
    @inlinable
    subscript(_ offset: Int) -> UInt8 {
        if isMultiSegment {
            return multiByte(at: offset)
        }
        return span[offset - base]
    }

    /// Multi-segment byte resolution: find the segment covering virtual `offset` and read it. Source segments read `span` (== `sourceBytes`); the interned newline segment yields `\n`.
    private func multiByte(at offset: Int) -> UInt8 {
        var v = 0
        for i in 0..<segments.count {
            let seg = segments[i]
            let len = Int(seg.length)
            if offset < v + len {
                let local = offset - v
                if seg.inSource {
                    return span[Int(seg.offset) + local]
                }
                // The only non-source segment in inline content is the shared interned `"\n"`.
                return UInt8(ascii: "\n")
            }
            v += len
        }
        return 0
    }

    /// The original-source byte offset for `offset`, or `nil` if it maps to a synthetic/arena byte. Single-segment source content maps identity (the offset already IS a source offset); single-segment arena content has no source mapping; multi-segment resolves through the segment list.
    @inlinable
    func sourceOffset(ofVirtual offset: Int) -> Int? {
        if !isMultiSegment {
            return inSource ? offset : nil
        }
        var v = 0
        for i in 0..<segments.count {
            let seg = segments[i]
            let len = Int(seg.length)
            if offset < v + len {
                return seg.inSource ? Int(seg.offset) + (offset - v) : nil
            }
            v += len
        }
        // One-past-the-end: map to just past the last source segment, if any.
        if segments.count > 0 {
            let last = segments[segments.count - 1]
            if last.inSource {
                return Int(last.offset) + Int(last.length)
            }
        }
        return nil
    }

    /// Build a `Chunk` for a sub-range of this content. Single-segment: a direct sub-chunk. Multi-segment: valid only when the range lies within one segment (the common case - inline nodes don't straddle a line join); callers that can straddle (code spans) handle materialization themselves.
    @inlinable
    func chunk(offset: Int, length: Int) -> Chunk {
        if !isMultiSegment {
            return Chunk(offset: offset, length: length, inSource: inSource)
        }
        var v = 0
        for i in 0..<segments.count {
            let seg = segments[i]
            let len = Int(seg.length)
            if offset < v + len {
                let local = offset - v
                return Chunk(offset: Int(seg.offset) + local, length: length, inSource: seg.inSource)
            }
            v += len
        }
        return .empty
    }

    /// Global offset of the next inline-significant byte at or after `globalCursor`, or `endOffset` if none remain. Used to skip plain-text runs in the inline dispatch loop without stepping byte by byte: a `SIMD16` scan compares 16 bytes at once against the significant set, recovering the first matching lane; a sub-16 tail is scanned scalar.
    ///
    /// The significant set must be a superset of the bytes the dispatch switch acts on. `~` and the GFM autolink triggers (`:` `@` `w`/`W`) are included only when their option is on - when off, the switch's case for them is a no-op (the byte becomes plain text), so skipping over them is equivalent. The contiguous cluster `[ \ ] ^ _ \``` (91...96) is one range compare.
    func nextSignificant(from globalCursor: Int, strikethrough: Bool, gfmAutolink: Bool, smart: Bool) -> Int {
        if isMultiSegment {
            return multiNextSignificant(from: globalCursor, strikethrough: strikethrough, gfmAutolink: gfmAutolink, smart: smart)
        }
        let n = span.count
        let startIdx = globalCursor - base
        if startIdx >= n {
            return endOffset
        }
        let found = span.withUnsafeBufferPointer { buf -> Int in
            guard let p = buf.baseAddress else { return n }
            return Self.scanSignificant(p, from: startIdx, to: n, strikethrough: strikethrough, gfmAutolink: gfmAutolink, smart: smart)
        }
        return base + found
    }

    /// Multi-segment `nextSignificant`: walk the segment list, SIMD-scanning each source segment's contiguous source sub-range via `scanSignificant`. The interned `"\n"` joining two lines is itself in the significant set (the dispatch emits a soft/hard break for it), so a newline segment's first byte is reported immediately without scanning. Cost is `SIMD(content bytes)` plus a tiny per-segment fixed cost - the same order as the single-segment fast path, not an O(bytes × segments) scalar walk.
    private func multiNextSignificant(from globalCursor: Int, strikethrough: Bool, gfmAutolink: Bool, smart: Bool) -> Int {
        let end = multiVirtualLength
        if globalCursor >= end {
            return end
        }
        // Locate the segment containing globalCursor (segment count per block is tiny).
        let count = segments.count
        var si = 0
        var segVStart = 0
        while si < count {
            let len = Int(segments[si].length)
            if globalCursor < segVStart + len {
                break
            }
            segVStart += len
            si += 1
        }
        return span.withUnsafeBufferPointer { buf -> Int in
            guard let p = buf.baseAddress else { return end }
            var i = si
            var vStart = segVStart
            var cursor = globalCursor
            while i < count {
                let seg = segments[i]
                let len = Int(seg.length)
                if seg.inSource {
                    let local = cursor - vStart                 // 0 once we advance past the entry segment
                    let absLo = Int(seg.offset) + local
                    let absHi = Int(seg.offset) + len
                    let foundAbs = Self.scanSignificant(p, from: absLo, to: absHi, strikethrough: strikethrough, gfmAutolink: gfmAutolink, smart: smart)
                    if foundAbs < absHi {
                        return vStart + (foundAbs - Int(seg.offset))
                    }
                } else {
                    // The only non-source segment in inline content is the shared interned "\n", which is always inline-significant - report its position directly.
                    return cursor
                }
                vStart += len
                cursor = vStart
                i += 1
            }
            return end
        }
    }

    /// SIMD16 scan of `p[lo..<hi]` for the first inline-significant byte; returns that index, or `hi` if none. Shared by the single-segment and per-segment (multi) scan paths so both get the vector fast path. The significant set must stay a superset of the dispatch switch's cases - see `nextSignificant`.
    @inline(__always)
    private static func scanSignificant(_ p: UnsafePointer<UInt8>, from lo: Int, to hi: Int, strikethrough: Bool, gfmAutolink: Bool, smart: Bool) -> Int {
        let clusterLo = SIMD16<UInt8>(repeating: 91)    // '['
        let clusterHi = SIMD16<UInt8>(repeating: 96)    // '`'
        let nl = SIMD16<UInt8>(repeating: UInt8(ascii: "\n"))
        let bang = SIMD16<UInt8>(repeating: UInt8(ascii: "!"))
        let amp = SIMD16<UInt8>(repeating: UInt8(ascii: "&"))
        let star = SIMD16<UInt8>(repeating: UInt8(ascii: "*"))
        let lt = SIMD16<UInt8>(repeating: UInt8(ascii: "<"))
        let tilde = SIMD16<UInt8>(repeating: UInt8(ascii: "~"))
        let colon = SIMD16<UInt8>(repeating: UInt8(ascii: ":"))
        let at = SIMD16<UInt8>(repeating: UInt8(ascii: "@"))
        let wCanon = SIMD16<UInt8>(repeating: UInt8(ascii: "w"))   // 'w'|0x20 == 'W'|0x20 == 'w'
        let lowerBit = SIMD16<UInt8>(repeating: 0x20)
        // Smart-punctuation triggers: straight quotes (`'` `"`), `-` (dashes), `.` (ellipsis).
        let squote = SIMD16<UInt8>(repeating: UInt8(ascii: "'"))
        let dquote = SIMD16<UInt8>(repeating: UInt8(ascii: "\""))
        let hyphen = SIMD16<UInt8>(repeating: UInt8(ascii: "-"))
        let period = SIMD16<UInt8>(repeating: UInt8(ascii: "."))
        let lanes = SIMD16<UInt8>(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
        let noMatch = SIMD16<UInt8>(repeating: 16)

        var i = lo
        while i + 16 <= hi {
            let v = UnsafeRawPointer(p + i).loadUnaligned(as: SIMD16<UInt8>.self)
            var m = ((v .>= clusterLo) .& (v .<= clusterHi))
                .| (v .== nl) .| (v .== bang) .| (v .== amp) .| (v .== star) .| (v .== lt)
            if strikethrough {
                m = m .| (v .== tilde)
            }
            if gfmAutolink {
                m = m .| (v .== colon) .| (v .== at) .| ((v | lowerBit) .== wCanon)
            }
            if smart {
                m = m .| (v .== squote) .| (v .== dquote) .| (v .== hyphen) .| (v .== period)
            }
            if any(m) {
                let lane = lanes.replacing(with: noMatch, where: .!m).min()
                return i + Int(lane)
            }
            i += 16
        }
        while i < hi {
            let b = p[i]
            let significant = (b >= 91 && b <= 96)
                || b == UInt8(ascii: "\n") || b == UInt8(ascii: "!") || b == UInt8(ascii: "&")
                || b == UInt8(ascii: "*") || b == UInt8(ascii: "<")
                || (strikethrough && b == UInt8(ascii: "~"))
                || (gfmAutolink && (b == UInt8(ascii: ":") || b == UInt8(ascii: "@") || (b | 0x20) == UInt8(ascii: "w")))
                || (smart && (b == UInt8(ascii: "'") || b == UInt8(ascii: "\"") || b == UInt8(ascii: "-") || b == UInt8(ascii: ".")))
            if significant {
                return i
            }
            i += 1
        }
        return hi
    }
}
