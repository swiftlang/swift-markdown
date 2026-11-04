/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

/// One block's content captured three ways for cross-checking the segment representation.
internal struct BlockContent {
    var kind: MarkdownNode.Kind
    var literal: String?
    var segmentsJoined: String
    var segmentCount: Int
    var info: String?
}

/// Collect every code/HTML block's content (literal, segment byte-join, segment count) in DFS order.
@available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
internal func collectCodeAndHTMLBlocks(_ doc: borrowing MarkdownDocument) -> [BlockContent] {
    var out: [BlockContent] = []
    visitBlocks(doc.root, into: &out)
    return out
}

@available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
private func visitBlocks(_ node: MarkdownNode, into out: inout [BlockContent]) {
    if node.kind.isCodeBlock || node.kind == .htmlBlock {
        var bytes: [UInt8] = []
        node.literalSegments().forEach { span in
            let raw = span.span
            for i in 0..<raw.count { bytes.append(raw[i]) }
        }
        out.append(BlockContent(
            kind: node.kind,
            literal: node.literal(),
            segmentsJoined: String(decoding: bytes, as: UTF8.self),
            segmentCount: node.literalSegments().count,
            info: node.kind.isCodeBlock ? node.codeBlockInfoString() : nil
        ))
    }
    node.children.forEach { child in
        visitBlocks(child, into: &out)
    }
}

/// Code and HTML block bodies are stored as zero-copy segment lists (source ranges joined by a shared interned `"\n"`), not materialized byte buffers. These tests assert two things for every shape: (1) the public `literal()` String is byte-identical to the joined body lines, and (2) `literalSegments()` concatenated byte-for-byte equals `literal()` - exercising the multi-segment read path that code/HTML blocks are the first production users of.
@Suite("Code/HTML block segment content")
struct CodeBlockSegmentTests {

    @available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
    private func firstBlock(
        _ matches: (MarkdownNode.Kind) -> Bool,
        in source: String,
        options: MarkdownDocument.ParseOptions = []
    ) throws -> BlockContent {
        return try MarkdownDocument.withParsedDocument(source, options: options) { doc in
            let blocks = collectCodeAndHTMLBlocks(doc)
            return try #require(blocks.first { matches($0.kind) }, "no matching block found")
        }
    }

    // MARK: - Fenced code

    @Test("fenced multi-line body is multi-segment and round-trips")
    func fencedMultiLine() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let r = try firstBlock(\.isCodeBlock, in: "```swift\nlet x = 1\nlet y = 2\nprint(x)\n```\n")
        #expect(r.literal == "let x = 1\nlet y = 2\nprint(x)\n")
        #expect(r.segmentsJoined == r.literal)
        #expect(r.segmentCount > 1)  // proves the body is held as multiple segments, not one copy
        #expect(r.info == "swift")
    }

    @Test("fenced single-line body")
    func fencedSingleLine() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let r = try firstBlock(\.isCodeBlock, in: "```\nonly line\n```\n")
        #expect(r.literal == "only line\n")
        #expect(r.segmentsJoined == r.literal)
    }

    @Test("fenced empty body has empty literal")
    func fencedEmpty() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let r = try firstBlock(\.isCodeBlock, in: "```\n```\n")
        #expect((r.literal ?? "") == "")
        #expect(r.segmentsJoined == "")
    }

    @Test("fenced body preserves a trailing blank line")
    func fencedTrailingBlank() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        // Fenced code keeps trailing blanks (unlike indented).
        let r = try firstBlock(\.isCodeBlock, in: "```\ncode\n\n```\n")
        #expect(r.literal == "code\n\n")
        #expect(r.segmentsJoined == r.literal)
    }

    @Test("fenced body preserves interior blank lines")
    func fencedInteriorBlanks() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let r = try firstBlock(\.isCodeBlock, in: "```\na\n\n\nb\n```\n")
        #expect(r.literal == "a\n\n\nb\n")
        #expect(r.segmentsJoined == r.literal)
    }

    // MARK: - Indented code

    @Test("indented multi-line body is multi-segment and round-trips")
    func indentedMultiLine() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let r = try firstBlock(\.isCodeBlock, in: "    line one\n    line two\n    line three\n")
        #expect(r.literal == "line one\nline two\nline three\n")
        #expect(r.segmentsJoined == r.literal)
        #expect(r.segmentCount > 1)
    }

    @Test("indented code strips trailing blank lines")
    func indentedStripsTrailingBlanks() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        // The blank lines after the indented line must be stripped (CommonMark §4.4).
        let r = try firstBlock(\.isCodeBlock, in: "    code\n\n\nmore text\n")
        #expect(r.literal == "code\n")
        #expect(r.segmentsJoined == r.literal)
    }

    @Test("indented code keeps interior blank lines but strips trailing")
    func indentedInteriorVsTrailing() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let r = try firstBlock(\.isCodeBlock, in: "    a\n\n    b\n\n\nparagraph\n")
        #expect(r.literal == "a\n\nb\n")
        #expect(r.segmentsJoined == r.literal)
    }

    // MARK: - Tab-expanded lines (force an arena-copy segment)

    @Test("tab-indented code body round-trips (forces non-source segment)")
    func tabIndentedCode() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        // A tab in the indentation triggers per-line tab expansion, so the body line does not map to source and is copied into the arena as an `inSource: false` segment. The literal must still be correct and the segment join must still equal it.
        let r = try firstBlock(\.isCodeBlock, in: "\tcode line one\n\tcode line two\n")
        #expect(r.literal == "code line one\ncode line two\n")
        #expect(r.segmentsJoined == r.literal)
    }

    // MARK: - CRLF

    @Test("CRLF fenced code normalizes line endings and round-trips")
    func crlfFenced() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let r = try firstBlock(\.isCodeBlock, in: "```\r\nx\r\ny\r\n```\r\n")
        #expect(r.literal == "x\ny\n")
        #expect(r.segmentsJoined == r.literal)
    }

    // MARK: - HTML blocks

    @Test("multi-line HTML block is multi-segment and round-trips")
    func htmlMultiLine() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let r = try firstBlock({ $0 == .htmlBlock }, in: "<div>\n  <p>hi</p>\n</div>\n")
        #expect(r.literal == "<div>\n  <p>hi</p>\n</div>\n")
        #expect(r.segmentsJoined == r.literal)
        #expect(r.segmentCount > 1)
    }

    @Test("single-line HTML block round-trips")
    func htmlSingleLine() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let r = try firstBlock({ $0 == .htmlBlock }, in: "<!-- comment -->\n")
        #expect(r.literal == "<!-- comment -->\n")
        #expect(r.segmentsJoined == r.literal)
    }
}

