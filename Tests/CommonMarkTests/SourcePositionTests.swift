/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

// DFS-collect each node's kind and source range. File-scope + `borrowing MarkdownNode` to satisfy the noncopyable-borrow rules (see code-conventions: bind docs to locals, use file-scope helpers).
internal func dfsRanges(
    _ node: borrowing MarkdownNode,
    into out: inout [(kind: MarkdownNode.Kind, range: Range<MarkdownNode.SourcePosition>?)]
) {
    out.append((node.kind, node.sourceRange))
    node.children.forEach { child in
        dfsRanges(child, into: &out)
    }
}

@Suite("Source positions - blocks")
struct SourcePositionTests {

    private typealias Pos = MarkdownNode.SourcePosition

    /// Find the first node whose kind matches `predicate` and return its range.
    private func range(
        in ranges: [(kind: MarkdownNode.Kind, range: Range<Pos>?)],
        where predicate: (MarkdownNode.Kind) -> Bool
    ) -> Range<Pos>? {
        for entry in ranges where predicate(entry.kind) {
            return entry.range
        }
        return nil
    }

    @Test("off by default - sourceRange is nil without .sourcePosition")
    func offByDefault() throws {
        let src = "# Hi\n\nHello\n"
        try MarkdownDocument.withParsedDocument(src) { doc in
        var ranges: [(kind: MarkdownNode.Kind, range: Range<Pos>?)] = []
        dfsRanges(doc.root, into: &ranges)
        #expect(ranges.allSatisfy { $0.range == nil })
        }
    }

    @Test("heading + paragraph start/end positions")
    func headingParagraph() throws {
        // "# Hi" on line 1, blank line 2, "Hello world" on line 3.
        let src = "# Hi\n\nHello world\n"
        try MarkdownDocument.withParsedDocument(src, options: .sourcePosition) { doc in
        var ranges: [(kind: MarkdownNode.Kind, range: Range<Pos>?)] = []
        dfsRanges(doc.root, into: &ranges)

        // MarkdownDocument spans the whole source: 1:1 .. just past "Hello world" (3:12).
        let docRange = ranges[0].range
        #expect(docRange?.lowerBound == Pos(line: 1, column: 1))
        #expect(docRange?.upperBound == Pos(line: 3, column: 12))

        let heading = range(in: ranges) { if case .heading = $0 { return true } else { return false } }
        #expect(heading?.lowerBound == Pos(line: 1, column: 1))
        #expect(heading?.upperBound == Pos(line: 1, column: 5))   // "# Hi" is 4 bytes

        let para = range(in: ranges) { $0 == .paragraph }
        #expect(para?.lowerBound == Pos(line: 3, column: 1))
        #expect(para?.upperBound == Pos(line: 3, column: 12))     // "Hello world" is 11 bytes
        }
    }

    @Test("block quote start/end")
    func blockQuote() throws {
        let src = "> quote\n"
        try MarkdownDocument.withParsedDocument(src, options: .sourcePosition) { doc in
        var ranges: [(kind: MarkdownNode.Kind, range: Range<Pos>?)] = []
        dfsRanges(doc.root, into: &ranges)
        let bq = range(in: ranges) { $0 == .blockQuote }
        #expect(bq?.lowerBound == Pos(line: 1, column: 1))   // the '>' marker
        #expect(bq?.upperBound == Pos(line: 1, column: 8))   // "> quote" is 7 bytes
        }
    }

    @Test("list item start columns")
    func listItems() throws {
        let src = "- a\n- b\n"
        try MarkdownDocument.withParsedDocument(src, options: .sourcePosition) { doc in
        var ranges: [(kind: MarkdownNode.Kind, range: Range<Pos>?)] = []
        dfsRanges(doc.root, into: &ranges)

        let list = range(in: ranges) { if case .list = $0 { return true } else { return false } }
        #expect(list?.lowerBound == Pos(line: 1, column: 1))

        // Both items start at column 1 (the bullet marker), on their own lines.
        var itemStarts: [Pos] = []
        for entry in ranges {
            if case .item = entry.kind, let lo = entry.range?.lowerBound { itemStarts.append(lo) }
        }
        #expect(itemStarts == [Pos(line: 1, column: 1), Pos(line: 2, column: 1)])
        }
    }

    @Test("columns are 1-based UTF-8 byte offsets (non-ASCII)")
    func byteColumns() throws {
        // "aé b": a(1 byte) é(2 bytes) space(1) b(1) = 5 bytes.
        let src = "aé b\n"
        try MarkdownDocument.withParsedDocument(src, options: .sourcePosition) { doc in
        var ranges: [(kind: MarkdownNode.Kind, range: Range<Pos>?)] = []
        dfsRanges(doc.root, into: &ranges)
        let para = range(in: ranges) { $0 == .paragraph }
        #expect(para?.lowerBound == Pos(line: 1, column: 1))
        // End column counts bytes, not characters: utf8.count (5) + 1 for the half-open upper bound.
        #expect(para?.upperBound == Pos(line: 1, column: "aé b".utf8.count + 1))
        }
    }

    @Test("indented code block start column accounts for indentation")
    func indentedCodeStart() throws {
        let src = "    code\n"
        try MarkdownDocument.withParsedDocument(src, options: .sourcePosition) { doc in
        var ranges: [(kind: MarkdownNode.Kind, range: Range<Pos>?)] = []
        dfsRanges(doc.root, into: &ranges)
        let code = range(in: ranges) { if case .codeBlock = $0 { return true } else { return false } }
        #expect(code?.lowerBound == Pos(line: 1, column: 5))   // 4 spaces then content
        }
    }
}
