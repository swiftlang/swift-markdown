/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// Byte-level scanners for link labels, destinations, titles, and the whitespace constructs that separate them.
///
/// They sit alongside the other parsing helpers and read `storage`/`sourceBytes` directly instead of taking them as parameters. They're used by both block-level reference-definition parsing (`BlockParser`) and inline link parsing (the InlineParser extensions).
///
/// The shared ASCII byte-classifier predicates (`isASCIISpace`, `isASCIIPunct`, `isASCIILetter`, `isASCIIDigit`) live on `UInt8` in `ASCIIByte.swift` so they're usable without a parser instance.
extension BlockParser {

    // MARK: - Link label

    internal struct LinkLabelMatch {
        var interior: Chunk
        var afterEnd: Int
    }

    /// Parse `[label]` per CommonMark §6.6 / §6.7. Returns the interior chunk (excluding brackets) and the offset just past the closing `]`. Allows ASCII `\X` escapes inside the label. Capped at 999 chars.
    internal func matchLinkLabel(_ chunk: Chunk) -> LinkLabelMatch? {
        let start = chunk.offset
        let end = chunk.range.upperBound
        if start >= end {
            return nil
        }
        if readByte(at: start, in: chunk) != UInt8(ascii: "[") {
            return nil
        }
        let interiorStart = start + 1
        var i = interiorStart
        var length = 0
        while i < end {
            let b = readByte(at: i, in: chunk)
            if b == UInt8(ascii: "[") {
                return nil
            }
            if b == UInt8(ascii: "]") {
                return LinkLabelMatch(
                    interior: chunk.extracting(1..<(i - start)),
                    afterEnd: i + 1
                )
            }
            if b == UInt8(ascii: "\\") {
                i += 1
                length += 1
                if i < end {
                    i += 1
                    length += 1
                }
            } else {
                i += 1
                length += 1
            }
            if length > 999 {
                return nil
            }
        }
        return nil
    }

    // MARK: - Link destination

    internal struct LinkDestinationMatch {
        var chunk: Chunk
        var afterEnd: Int
    }

    /// Parse a link destination - either `<...>` (no internal `<`, `>`, or unescaped newline) or a bare URL (no whitespace, balanced parens up to depth 32, ASCII `\X` escapes).
    internal func matchLinkDestination(_ chunk: Chunk) -> LinkDestinationMatch? {
        let start = chunk.offset
        let end = chunk.range.upperBound
        if start >= end {
            return nil
        }
        let first = readByte(at: start, in: chunk)
        if first == UInt8(ascii: "<") {
            var i = start + 1
            while i < end {
                let c = readByte(at: i, in: chunk)
                if c == UInt8(ascii: ">") {
                    return LinkDestinationMatch(chunk: chunk.extracting(1..<(i - start)), afterEnd: i + 1)
                }
                if c == UInt8(ascii: "\\") {
                    i += 2
                    continue
                }
                if c == UInt8(ascii: "\n") || c == UInt8(ascii: "<") {
                    return nil
                }
                i += 1
            }
            return nil
        }
        if first.isASCIISpace {
            return nil
        }
        var i = start
        var nbParen = 0
        while i < end {
            let c = readByte(at: i, in: chunk)
            if c == UInt8(ascii: "\\") && i + 1 < end {
                i += 2
                continue
            }
            if c == UInt8(ascii: "(") {
                nbParen += 1
                if nbParen > 32 {
                    return nil
                }
                i += 1
                continue
            }
            if c == UInt8(ascii: ")") {
                if nbParen == 0 {
                    break
                }
                nbParen -= 1
                i += 1
                continue
            }
            if c.isASCIISpace {
                if i == start {
                    return nil
                }
                break
            }
            i += 1
        }
        // Empty bare URL is allowed for inline links - `[a]()` should match with an empty destination.
        return LinkDestinationMatch(chunk: chunk.extracting(0..<(i - start)), afterEnd: i)
    }

    // MARK: - Link title

    internal struct LinkTitleMatch {
        var chunk: Chunk
        var afterEnd: Int
    }

    /// Match `"…"`, `'…'`, or `(…)` with ASCII `\X` escapes. Parens form disallows unescaped `(` inside.
    internal func matchLinkTitle(_ chunk: Chunk) -> LinkTitleMatch? {
        let start = chunk.offset
        let end = chunk.range.upperBound
        if start >= end {
            return nil
        }
        let opener = readByte(at: start, in: chunk)
        let closer: UInt8
        let parens: Bool
        switch opener {
        case UInt8(ascii: "\""):
            closer = UInt8(ascii: "\"")
            parens = false
        case UInt8(ascii: "'"):
            closer = UInt8(ascii: "'")
            parens = false
        case UInt8(ascii: "("):
            closer = UInt8(ascii: ")")
            parens = true
        default:
            return nil
        }
        var i = start + 1
        while i < end {
            let c = readByte(at: i, in: chunk)
            if c == UInt8(ascii: "\\") {
                i += 2
                continue
            }
            if c == closer {
                return LinkTitleMatch(chunk: chunk.extracting(1..<(i - start)), afterEnd: i + 1)
            }
            if parens && c == UInt8(ascii: "(") {
                return nil
            }
            i += 1
        }
        return nil
    }

    // MARK: - Whitespace

    /// Skip zero or more space and tab bytes only, from `cursor` up to the end of `chunk`.
    internal func skipSpacesTabs(from cursor: Int, in chunk: Chunk) -> Int {
        let end = chunk.range.upperBound
        var i = cursor
        while i < end {
            let c = readByte(at: i, in: chunk)
            if c != UInt8(ascii: " ") && c != UInt8(ascii: "\t") {
                break
            }
            i += 1
        }
        return i
    }

    /// `spnl` from cmark: zero or more spaces/tabs, then *at most one* line end (`\n`, `\r\n`, or `\r`), then more spaces/tabs. Scans from `cursor` up to the end of `chunk`.
    internal func skipSpacesAndOneLineEnd(from cursor: Int, in chunk: Chunk) -> Int {
        let end = chunk.range.upperBound
        var i = skipSpacesTabs(from: cursor, in: chunk)
        if i >= end {
            return i
        }
        let c = readByte(at: i, in: chunk)
        if c == UInt8(ascii: "\r") {
            i += 1
            if i < end && readByte(at: i, in: chunk) == UInt8(ascii: "\n") {
                i += 1
            }
            i = skipSpacesTabs(from: i, in: chunk)
        } else if c == UInt8(ascii: "\n") {
            i += 1
            i = skipSpacesTabs(from: i, in: chunk)
        }
        return i
    }

    /// Match `\r\n`, `\n`, `\r`, or end-of-input at `cursor`. Returns the offset just past the line ending, or `nil` if `cursor` is neither at a line end nor at the end of `chunk`.
    internal func skipLineEndOrEOF(from cursor: Int, in chunk: Chunk) -> Int? {
        let end = chunk.range.upperBound
        if cursor >= end {
            return cursor
        }
        let c = readByte(at: cursor, in: chunk)
        if c == UInt8(ascii: "\r") {
            var i = cursor + 1
            if i < end && readByte(at: i, in: chunk) == UInt8(ascii: "\n") {
                i += 1
            }
            return i
        }
        if c == UInt8(ascii: "\n") {
            return cursor + 1
        }
        return nil
    }

    // MARK: - Label normalization

    /// CommonMark §4.7 normalization: trim outer whitespace, collapse interior whitespace runs to a single space, then full Unicode case-fold (`String.lowercased()`) so labels match across scripts - `[ΑΓΩ]` and `[αγω]` resolve to the same key.
    internal func normalizeLabel(chunk: Chunk) -> String {
        let span = if chunk.inSource {
            sourceBytes.extracting(chunk.range)
        } else {
            storage.strings.span.extracting(chunk.range)
        }

        return Self.normalizeLabel(span)
    }

    /// CommonMark §4.7 normalization over an already-resolved span. The byte-level worker behind `normalizeLabel(chunk:)`; `static` because it touches no parser state.
    private static func normalizeLabel(_ span: Span<UInt8>) -> String {
        String(unsafeUninitializedCapacity: span.count) { buffer in
            var output = OutputSpan(buffer: buffer, initializedCount: 0)
            var pendingSpace = false

            for i in 0..<span.count {
                let b = span[i]
                switch b {
                case UInt8(ascii: " "), UInt8(ascii: "\t"),
                     UInt8(ascii: "\n"), UInt8(ascii: "\r"):
                    if !output.isEmpty {
                        pendingSpace = true
                    }
                    continue
                default:
                    break
                }
                if pendingSpace {
                    output.append(UInt8(ascii: " "))
                    pendingSpace = false
                }
                output.append(b)
            }

            return output.finalize(for: buffer)
        }.lowercased()
    }
}
