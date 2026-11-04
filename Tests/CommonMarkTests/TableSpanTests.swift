/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

/// Tests for `.tableSpans` and `.tableRowspanDitto`, which let GFM table cells span columns and rows.
@Suite("Parse options - table spans")
struct TableSpanTests {

    /// `(columns, rows, text)` for each cell of each row of the first table in the document.
    private func tableSpans(_ doc: borrowing MarkdownDocument) -> [[(columns: Int, rows: Int, text: String)]] {
        var rows: [[(columns: Int, rows: Int, text: String)]] = []
        var found = false
        let root = doc.root
        root.children.forEach { block in
            if found || block.kind != .table { return }
            found = true
            block.children.forEach { row in
                guard case .tableRow = row.kind else { return }
                var cells: [(columns: Int, rows: Int, text: String)] = []
                row.children.forEach { cell in
                    guard case .tableCell(_, let columns, let rows) = cell.kind else { return }
                    var text = ""
                    cell.children.forEach { inline in
                        if let lit = inline.literal() { text += lit }
                    }
                    cells.append((columns, rows, text))
                }
                rows.append(cells)
            }
        }
        return rows
    }

    // MARK: - colspan

    @Test("an empty `||` cell becomes a colspan filler and grows the cell to its left")
    func colspan() throws {
        let source = """
        | a | b | c |
        |---|---|---|
        | x || y |
        """
        let rows = try MarkdownDocument.withParsedDocument(source, options: [.tables, .tableSpans]) { tableSpans($0) }
        // Header: three ordinary 1×1 cells.
        #expect(rows[0].map(\.columns) == [1, 1, 1])
        // Body: `x` spans two columns, the `||` cell is a 0-column filler, `y` is ordinary.
        #expect(rows[1].map(\.columns) == [2, 0, 1])
        #expect(rows[1].map(\.text) == ["x", "", "y"])
    }

    @Test("a whitespace-only cell does NOT trigger a colspan")
    func whitespaceCellIsNotColspan() throws {
        let source = """
        | a | b | c |
        |---|---|---|
        | x |  | y |
        """
        let rows = try MarkdownDocument.withParsedDocument(source, options: [.tables, .tableSpans]) { tableSpans($0) }
        #expect(rows[1].map(\.columns) == [1, 1, 1])
    }

    // MARK: - rowspan

    @Test("a `^` cell becomes a rowspan filler and grows the cell above")
    func rowspan() throws {
        let source = """
        | a | b |
        |---|---|
        | x | y |
        | ^ | z |
        """
        let rows = try MarkdownDocument.withParsedDocument(source, options: [.tables, .tableSpans]) { tableSpans($0) }
        // First body row: `x` now spans two rows.
        #expect(rows[1].map(\.rows) == [2, 1])
        #expect(rows[1].map(\.text) == ["x", "y"])
        // Second body row: the `^` cell is a 0-row filler with its marker text suppressed.
        #expect(rows[2].map(\.rows) == [0, 1])
        #expect(rows[2].map(\.text) == ["", "z"])
    }

    @Test("without .tableRowspanDitto, a `\"` cell is not a rowspan marker")
    func dittoRequiresOption() throws {
        let source = """
        | a | b |
        |---|---|
        | x | y |
        | " | z |
        """
        let rows = try MarkdownDocument.withParsedDocument(source, options: [.tables, .tableSpans]) { tableSpans($0) }
        // `"` is ordinary content (curly-quote smart is off): no span, text preserved.
        #expect(rows[1].map(\.rows) == [1, 1])
        #expect(rows[2].map(\.rows) == [1, 1])
        #expect(rows[2][0].text == "\"")
    }

    @Test("with .tableRowspanDitto, a `\"` cell acts as the rowspan marker")
    func dittoMarker() throws {
        let source = """
        | a | b |
        |---|---|
        | x | y |
        | " | z |
        """
        let rows = try MarkdownDocument.withParsedDocument(source, options: [.tables, .tableSpans, .tableRowspanDitto]) { tableSpans($0) }
        #expect(rows[1].map(\.rows) == [2, 1])
        #expect(rows[2].map(\.rows) == [0, 1])
        #expect(rows[2][0].text == "")
    }

    // MARK: - option gating

    @Test("without .tableSpans every cell is an ordinary 1x1 cell")
    func spansDisabled() throws {
        let source = """
        | a | b | c |
        |---|---|---|
        | x || y |
        """
        let rows = try MarkdownDocument.withParsedDocument(source, options: .tables) { tableSpans($0) }
        for row in rows {
            #expect(row.allSatisfy { $0.columns == 1 && $0.rows == 1 })
        }
    }
}
