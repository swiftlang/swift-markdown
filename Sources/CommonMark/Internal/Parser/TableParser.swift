/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

internal import BasicContainers

/// GFM-tables detection and transformation.
///
/// Called from `BlockParser.finalize` for `.paragraph` nodes when the `.tables` parse option is set. If the paragraph's content matches the GFM table pattern (header line containing `|` followed by a delimiter line of `:?-+:?` cells), the paragraph node is mutated in place into a `.table` node with `.tableRow` / `.tableCell` descendants.
extension BlockParser {

    /// Try to transform `node` (a `.paragraph`) and its content `chunk` into a `.table`.
    /// Only supports reading from the standard source (not materialized strings).
    /// Returns `true` on success (caller should skip inline-parsing the original paragraph since the cells were already inline-parsed). Returns `false` when the chunk doesn't match the table pattern.
    internal mutating func parseTable(node: DocumentStorage.Index, chunk inputChunk: Chunk) throws(MarkdownDocument.Error) -> Bool {
        // The table machinery (line splitting, cell extraction, pipe-unescape) reads exclusively from `storage.strings`. Paragraph content is usually already materialized there, but the source-contiguity fast path can hand us an `inSource` chunk (a zero-copy multi-line source range). A table's header (first) line must contain an unescaped `|`, so before paying for a copy we scan the chunk's first line directly in the source: no pipe there means this paragraph can't be a table and we bail without materializing - which keeps the overwhelmingly common non-table paragraph zero-copy. Only when a pipe is present do we copy into the arena so the rest of this function can address it uniformly. Only paid when `.tables` is enabled.
        let chunk: Chunk
        // When the content came in as a zero-copy `inSource` range, the arena copy below is a byte-for-byte image of the source, so any arena offset `A` maps back to source offset `A + sourceDelta`. That lets us stamp source positions onto rows/cells/cell-text. Content that arrived already materialized (blockquote/list/CRLF tables) has no contiguous source image, so positions are left unstamped.
        let sourceMapped: Bool
        let sourceDelta: Int
        if inputChunk.inSource {
            if !sourceFirstLineHasPipe(chunk: inputChunk) {
                return false
            }
            let offset = storage.strings.count
            for i in inputChunk.offset..<(inputChunk.offset + inputChunk.length) {
                storage.strings.append(sourceBytes[i])
            }
            chunk = Chunk(offset: offset, length: inputChunk.length, inSource: false)
            sourceMapped = positionsEnabled
            sourceDelta = inputChunk.offset - offset
        } else {
            chunk = inputChunk
            sourceMapped = false
            sourceDelta = 0
        }
        let lines = splitLines(chunk: chunk)
        if lines.count < 2 {
            return false
        }
        let header = lines[0]
        let delimLine = lines[1]
        if !lineContainsPipe(line: header) {
            return false
        }
        guard let alignments = parseDelimRow(line: delimLine) else {
            return false
        }
        let columnCount = alignments.count
        if columnCount == 0 {
            return false
        }
        // GFM: header column count must equal delimiter column count, else not a table - leave the paragraph alone.
        let headerCells = splitCells(line: header)
        if headerCells.count != columnCount {
            return false
        }
        // Materialize alignments into the per-document table-alignment array.
        let alignmentsOffset = storage.tableAlignments.count
        for a in alignments {
            storage.tableAlignments.append(a)
        }
        // Mutate the paragraph node in place.
        storage[node].kind = .table
        storage[node].data = .table(
            columnCount: columnCount,
            alignmentsOffset: alignmentsOffset
        )
        let spansEnabled = storage.options.contains(.tableSpans)
        let dittoEnabled = storage.options.contains(.tableRowspanDitto)
        // Cell node indices for every row built so far, so a rowspan marker can find the cell above it. Only tracked when `.tableSpans` is on - otherwise it stays empty (no allocation) and the span machinery is skipped entirely, keeping the common table path identical to a span-free build.
        var previousRows: [[DocumentStorage.Index]] = []
        // Header row.
        let headerCellIndices = try appendRow(
            parent: node,
            line: header,
            alignments: alignments,
            isHeader: true,
            spansEnabled: spansEnabled,
            dittoEnabled: dittoEnabled,
            previousRows: previousRows,
            sourceMapped: sourceMapped,
            sourceDelta: sourceDelta
        )
        if spansEnabled {
            previousRows.append(headerCellIndices)
        }
        // Body rows. Each subsequent line becomes one `.tableRow`.
        for k in 2..<lines.count {
            let cells = try appendRow(
                parent: node,
                line: lines[k],
                alignments: alignments,
                isHeader: false,
                spansEnabled: spansEnabled,
                dittoEnabled: dittoEnabled,
                previousRows: previousRows,
                sourceMapped: sourceMapped,
                sourceDelta: sourceDelta
            )
            if spansEnabled {
                previousRows.append(cells)
            }
        }
        return true
    }

    // MARK: - Row construction

    /// Build a `.tableRow` node + its cells under `parent`. Missing trailing cells are emitted as empty; extras beyond `columnCount` are dropped.
    ///
    /// When `spansEnabled`, each cell carries `.tableCell` span data: an empty `||` cell becomes a colspan filler (colspan 0) and grows the preceding cell's colspan; a cell whose content is the lone rowspan marker (`^`, or `"` when `dittoEnabled`) becomes a rowspan filler (rowspan 0) and grows the matching cell in the nearest non-filler row above, with its marker text suppressed. Returns the row's cell node indices (for the next row's rowspan resolution).
    @discardableResult
    private mutating func appendRow(
        parent: DocumentStorage.Index,
        line: Range<Int>,
        alignments: [MarkdownNode.TableAlignment],
        isHeader: Bool,
        spansEnabled: Bool,
        dittoEnabled: Bool,
        previousRows: [[DocumentStorage.Index]],
        sourceMapped: Bool,
        sourceDelta: Int
    ) throws(MarkdownDocument.Error) -> [DocumentStorage.Index] {
        let rowIdx = storage.appendNode(NodeRecord(
            kind: .tableRow(isHeader: isHeader),
            parent: parent,
            data: nil
        ))
        storage.appendChild(rowIdx, to: parent)
        // The row spans its whole source line.
        if sourceMapped {
            storage.setSourceStart(rowIdx, line.lowerBound + sourceDelta)
            storage.setSourceEnd(rowIdx, line.upperBound + sourceDelta)
        }
        let cells = splitCells(line: line)
        let columnCount = alignments.count

        // Span bookkeeping is only allocated/computed when `.tableSpans` is on. With spans off these stay empty (the empty `Array` is a non-allocating singleton) and every per-cell read below is guarded by `spansEnabled`, so the common table path does no extra allocation or work.
        var colspans: [Int] = []
        var rowspans: [Int] = []
        var skipContent: [Bool] = []
        var cellIndices: [DocumentStorage.Index] = []
        if spansEnabled {
            colspans = [Int](repeating: 1, count: columnCount)
            rowspans = [Int](repeating: 1, count: columnCount)
            skipContent = [Bool](repeating: false, count: columnCount)
            cellIndices.reserveCapacity(columnCount)
            let markerByte = dittoEnabled ? UInt8(ascii: "\"") : UInt8(ascii: "^")
            for col in 0..<min(columnCount, cells.count) {
                let raw = cells[col]
                // Colspan filler: a literally empty (`||`, zero-width) cell that isn't the first column.
                if col > 0 && raw.isEmpty {
                    colspans[col] = 0
                    var j = col - 1
                    while j >= 0 {
                        if colspans[j] > 0 {
                            colspans[j] += 1
                            break
                        }
                        j -= 1
                    }
                }
                // Rowspan marker: the trimmed cell is exactly the marker byte.
                let trimmed = trimSpaceTabs(range: raw)
                if trimmed.count == 1 && storage.strings[trimmed.lowerBound] == markerByte {
                    rowspans[col] = 0
                }
            }
            // Resolve rowspan markers against the cell directly above (body rows only - the header has no row above). Scan upward past filler rows to the cell that owns the span and grow it.
            if !isHeader {
                for col in 0..<columnCount where rowspans[col] == 0 {
                    var r = previousRows.count - 1
                    var spanning: DocumentStorage.Index? = nil
                    while r >= 0 {
                        let prev = previousRows[r]
                        guard col < prev.count else { break }
                        let candidate = prev[col]
                        if cellRowspan(candidate) == 0 {
                            r -= 1
                            continue
                        }
                        spanning = candidate
                        break
                    }
                    if let spanning {
                        setCellRowspan(spanning, cellRowspan(spanning) + 1)
                        skipContent[col] = true
                    }
                }
            }
        }

        // One pair of reusable inline-scratch stacks for all cells in this row.
        var delimiters = UniqueArray<DelimiterRecord>()
        var brackets = UniqueArray<BracketRecord>()
        // Reused content scratch for all cells in this row. Owned here so its borrow stays independent of the `storage` mutations `parseInline` performs. Cell chunks are always arena-backed (`inSource == false`).
        var scratch = UniqueArray<UInt8>()
        for col in 0..<columnCount {
            let alignment = alignments[col]
            let cellIdx = storage.appendNode(NodeRecord(
                kind: .tableCell(
                    alignment: alignment,
                    columns: spansEnabled ? colspans[col] : 1,
                    rows: spansEnabled ? rowspans[col] : 1
                ),
                parent: rowIdx,
                data: nil
            ))
            storage.appendChild(cellIdx, to: rowIdx)
            if spansEnabled {
                cellIndices.append(cellIdx)
            }
            // Stamp the cell's source range: the full between-pipes span (including surrounding whitespace). cmark gives an empty `||` filler cell a 1-column-wide range, so widen a zero-width split range by one byte.
            if sourceMapped, col < cells.count {
                let cr = cells[col]
                storage.setSourceStart(cellIdx, cr.lowerBound + sourceDelta)
                storage.setSourceEnd(cellIdx, (cr.isEmpty ? cr.lowerBound + 1 : cr.upperBound) + sourceDelta)
            }
            if col < cells.count && !(spansEnabled && skipContent[col]) {
                let cellRange = trimSpaceTabs(range: cells[col])
                if !cellRange.isEmpty {
                    // Pre-process: replace `\|` with `|` so that whatever pipe-escaping the writer used to keep the cell intact is invisible to inline parsing - even inside a code span.
                    let cellChunk = unescapePipes(range: cellRange)
                    // No `\|` was present iff `unescapePipes` returned the range unchanged. In that case (and when the table maps to source) the cell content is a contiguous source slice, so parse it through a source-backed `ContentSpan` and inline stamping lands real source positions on the cell's text/code/etc. Otherwise fall back to an arena copy (no inline positions - the escaped bytes don't map).
                    let noEscape = cellChunk.offset == cellRange.lowerBound && cellChunk.length == cellRange.count
                    if sourceMapped && noEscape {
                        let srcLo = cellRange.lowerBound + sourceDelta
                        let srcHi = cellRange.upperBound + sourceDelta
                        try parseInline(
                            content: ContentSpan(span: sourceBytes.extracting(srcLo..<srcHi), base: srcLo, inSource: true),
                            into: cellIdx,
                            delimiters: &delimiters, brackets: &brackets
                        )
                    } else {
                        scratch.removeAll(keepingCapacity: true)
                        do {
                            let copyMe = storage.strings.span.extracting(cellChunk.range)
                            copyMe.withUnsafeBufferPointer { buffer in
                                scratch.append(copying: buffer)
                            }
                        }
                        try parseInline(
                            content: ContentSpan(span: scratch.span, base: cellChunk.offset, inSource: cellChunk.inSource),
                            into: cellIdx,
                            delimiters: &delimiters, brackets: &brackets
                        )
                    }
                }
            }
        }
        return cellIndices
    }

    /// Current rowspan of a `.tableCell` node (`1` if it carries no span data).
    private func cellRowspan(_ idx: DocumentStorage.Index) -> Int {
        if case .tableCell(_, _, let rowspan) = storage[idx].kind {
            return rowspan
        }
        return 1
    }

    /// Set the rowspan of a `.tableCell` node, preserving its alignment and colspan.
    private mutating func setCellRowspan(_ idx: DocumentStorage.Index, _ value: Int) {
        if case .tableCell(let alignment, let colspan, _) = storage[idx].kind {
            storage[idx].kind = .tableCell(alignment: alignment, columns: colspan, rows: value)
        }
    }

    /// If `range` (in `storage.strings`) contains any `\|` sequences, materialize a copy with each replaced by `|` and return a chunk pointing at the new region. Otherwise return a chunk pointing at the original range.
    private mutating func unescapePipes(range: Range<Int>) -> Chunk {
        var hasEscape = false
        var i = range.lowerBound
        while i + 1 < range.upperBound {
            if storage.strings[i] == UInt8(ascii: "\\")
                && storage.strings[i + 1] == UInt8(ascii: "|") {
                hasEscape = true
                break
            }
            i += 1
        }
        if !hasEscape {
            return Chunk(
                offset: range.lowerBound,
                length: range.count,
                inSource: false
            )
        }
        let outOffset = storage.strings.count
        var j = range.lowerBound
        while j < range.upperBound {
            let b = storage.strings[j]
            if b == UInt8(ascii: "\\"), j + 1 < range.upperBound,
               storage.strings[j + 1] == UInt8(ascii: "|") {
                storage.strings.append(UInt8(ascii: "|"))
                j += 2
                continue
            }
            storage.strings.append(b)
            j += 1
        }
        return Chunk(
            offset: outOffset,
            length: storage.strings.count - outOffset,
            inSource: false
        )
    }

    // MARK: - Line / cell splitting

    /// Split `chunk` on `\n` boundaries. Returns ranges into `storage.strings` (caller must have `chunk.inSource == false`).
    private mutating func splitLines(chunk: Chunk) -> [Range<Int>] {
        var lines: [Range<Int>] = []
        let endOff = chunk.offset + chunk.length
        var i = chunk.offset
        var lineStart = i
        while i < endOff {
            if storage.strings[i] == UInt8(ascii: "\n") {
                lines.append(lineStart..<i)
                lineStart = i + 1
            }
            i += 1
        }
        if lineStart < endOff {
            lines.append(lineStart..<endOff)
        }
        return lines
    }

    /// `true` if `line` contains a `|` that isn't backslash-escaped.
    private func lineContainsPipe(line: Range<Int>) -> Bool {
        var i = line.lowerBound
        while i < line.upperBound {
            let b = storage.strings[i]
            if b == UInt8(ascii: "\\") && i + 1 < line.upperBound {
                i += 2
                continue
            }
            if b == UInt8(ascii: "|") {
                return true
            }
            i += 1
        }
        return false
    }

    /// `true` if the first line of an `inSource` `chunk` contains an unescaped `|`, reading directly from `sourceBytes` without materializing. A table's header line must contain a pipe, so this is the cheap necessary-condition gate that keeps non-table paragraphs zero-copy. This runs for every paragraph (when `.tables` is on) and is roughly one linear pass over all first-line bytes, so the scan is vectorized like `LineReader`: 16 bytes per step, stopping at the first byte of interest (`|`, `\n`, or `\`). Only LF endings reach an `inSource` chunk (CRLF/CR paragraphs are materialized), so `\n` is the sole terminator to watch for.
    private func sourceFirstLineHasPipe(chunk: Chunk) -> Bool {
        let endOff = chunk.offset + chunk.length
        return sourceBytes.withUnsafeBufferPointer { buf -> Bool in
            guard let base = buf.baseAddress else { return false }
            let pipe = SIMD16<UInt8>(repeating: UInt8(ascii: "|"))
            let nl = SIMD16<UInt8>(repeating: UInt8(ascii: "\n"))
            let bs = SIMD16<UInt8>(repeating: UInt8(ascii: "\\"))
            let lanes = SIMD16<UInt8>(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
            let noMatch = SIMD16<UInt8>(repeating: 16)
            var i = chunk.offset
            while i < endOff {
                // Vectorized skip over uninteresting bytes; stop at the first `|`, `\n`, or `\`.
                if i + 16 <= endOff {
                    let c = UnsafeRawPointer(base + i).loadUnaligned(as: SIMD16<UInt8>.self)
                    let matched = (c .== pipe) .| (c .== nl) .| (c .== bs)
                    if !any(matched) {
                        i += 16
                        continue
                    }
                    i += Int(lanes.replacing(with: noMatch, where: .!matched).min())
                }
                // Scalar handling of the byte at `i` (a SIMD match, or the sub-16 tail).
                let b = base[i]
                if b == UInt8(ascii: "\n") {
                    return false
                }
                if b == UInt8(ascii: "|") {
                    return true
                }
                if b == UInt8(ascii: "\\") && i + 1 < endOff {
                    i += 2
                    continue
                }
                i += 1
            }
            return false
        }
    }

    /// Parse the delimiter row into per-column alignments. Returns nil if the line isn't a valid delimiter row. Each cell must match `\s*:?-+:?\s*` after pipe splitting, with at least one column.
    private func parseDelimRow(line: Range<Int>) -> [MarkdownNode.TableAlignment]? {
        let cells = splitCells(line: line)
        if cells.isEmpty {
            return nil
        }
        var alignments: [MarkdownNode.TableAlignment] = []
        alignments.reserveCapacity(cells.count)
        for cell in cells {
            let trimmed = trimSpaceTabs(range: cell)
            if trimmed.isEmpty {
                return nil
            }
            var s = trimmed.lowerBound
            var e = trimmed.upperBound
            var leftColon = false
            var rightColon = false
            if storage.strings[s] == UInt8(ascii: ":") {
                leftColon = true
                s += 1
            }
            if e > s && storage.strings[e - 1] == UInt8(ascii: ":") {
                rightColon = true
                e -= 1
            }
            if s >= e {
                return nil
            }
            for j in s..<e {
                if storage.strings[j] != UInt8(ascii: "-") {
                    return nil
                }
            }
            let a: MarkdownNode.TableAlignment
            switch (leftColon, rightColon) {
            case (true, true): a = .center
            case (true, false): a = .left
            case (false, true): a = .right
            case (false, false): a = .none
            }
            alignments.append(a)
        }
        return alignments
    }

    /// Split `line` into cells on unescaped `|`. Strips a single leading and trailing `|` if present (with optional surrounding whitespace).
    private func splitCells(line: Range<Int>) -> [Range<Int>] {
        var s = line.lowerBound
        var e = line.upperBound
        while s < e && storage.strings[s].isSpaceOrTab {
            s += 1
        }
        while e > s && storage.strings[e - 1].isSpaceOrTab {
            e -= 1
        }
        if s < e && storage.strings[s] == UInt8(ascii: "|") {
            s += 1
        }
        if e > s && storage.strings[e - 1] == UInt8(ascii: "|") {
            // Don't strip a backslash-escaped pipe.
            if e - 2 < s || storage.strings[e - 2] != UInt8(ascii: "\\") {
                e -= 1
            }
        }
        var cells: [Range<Int>] = []
        var cellStart = s
        var i = s
        while i < e {
            let b = storage.strings[i]
            if b == UInt8(ascii: "\\") && i + 1 < e {
                i += 2
                continue
            }
            if b == UInt8(ascii: "|") {
                cells.append(cellStart..<i)
                cellStart = i + 1
            }
            i += 1
        }
        cells.append(cellStart..<e)
        return cells
    }

    private func trimSpaceTabs(range: Range<Int>) -> Range<Int> {
        var s = range.lowerBound
        var e = range.upperBound
        while s < e && storage.strings[s].isSpaceOrTab {
            s += 1
        }
        while e > s && storage.strings[e - 1].isSpaceOrTab {
            e -= 1
        }
        return s..<e
    }
}
