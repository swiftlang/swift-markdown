/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

/// Walks a document and returns a compact `(kind, optional-literal)` sequence in DFS order. Useful for asserting the shape of parsed trees in tests without writing nested forEach blocks.
internal func dfs(_ doc: borrowing MarkdownDocument) -> [(kind: MarkdownNode.Kind, literal: String?)] {
    var out: [(MarkdownNode.Kind, String?)] = []
    visit(doc.root, into: &out)
    return out.map { ($0.0, $0.1) }
}

private func visit(_ node: borrowing MarkdownNode, into out: inout [(MarkdownNode.Kind, String?)]) {
    out.append((node.kind, node.literal()))
    node.children.forEach { child in
        visit(child, into: &out)
    }
}

// Shape-assertion helpers: build the `Kind` value a freshly-parsed list / indented code block carries, so structural `kinds == [...]` arrays stay readable. (`.list`/`.codeBlock` carry associated metadata.)
extension MarkdownNode.Kind {
    static func bulletList(
        _ marker: MarkdownNode.ListInfo.BulletMarker = .hyphen,
        tight: Bool = true
    ) -> MarkdownNode.Kind {
        .list(.init(kind: .bullet, start: 1, tight: tight, orderedDelimiter: .period, bulletMarker: marker))
    }

    static func orderedList(
        start: Int = 1,
        _ delimiter: MarkdownNode.ListInfo.OrderedDelimiter = .period,
        tight: Bool = true
    ) -> MarkdownNode.Kind {
        .list(.init(kind: .ordered, start: start, tight: tight, orderedDelimiter: delimiter, bulletMarker: .hyphen))
    }

    /// An indented (non-fenced) code block.
    static let indentedCode = MarkdownNode.Kind.codeBlock(
        .init(isFenced: false, fenceCharacter: nil, fenceLength: 0, fenceOffset: 0)
    )

    /// A fenced code block.
    static func fencedCode(
        _ character: MarkdownNode.CodeBlockInfo.FenceCharacter = .backtick,
        length: Int = 3,
        offset: Int = 0
    ) -> MarkdownNode.Kind {
        .codeBlock(.init(isFenced: true, fenceCharacter: character, fenceLength: length, fenceOffset: offset))
    }
}

@Suite("Block parser - paragraphs")
struct ParagraphTests {

    @Test("single-line paragraph")
    func singleLine() throws {
        let source = "hello world"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape.count == 3)
        #expect(shape[0].kind == .document)
        #expect(shape[1].kind == .paragraph)
        #expect(shape[2].kind == .text)
        #expect(shape[2].literal == "hello world")
        }
    }

    @Test("multi-line paragraph splits into text + softBreak nodes")
    func multiLine() throws {
        let source = "first line\nsecond line\nthird"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        let kinds = shape.map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text, .softBreak, .text, .softBreak, .text])
        let texts = shape.compactMap { $0.literal }
        #expect(texts == ["first line", "second line", "third"])
        }
    }

    @Test("blank line separates paragraphs")
    func blankLineSeparates() throws {
        let source = "first paragraph\n\nsecond paragraph"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        let kinds = shape.map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text, .paragraph, .text])
        let texts = shape.compactMap { $0.literal }
        #expect(texts == ["first paragraph", "second paragraph"])
        }
    }

    @Test("multiple blank lines collapse to one separator")
    func multipleBlankLines() throws {
        let source = "one\n\n\n\ntwo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text, .paragraph, .text])
        }
    }

    @Test("trailing newline doesn't produce extra empty paragraph")
    func trailingNewline() throws {
        let source = "alone\n"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text])
        }
    }

    @Test("CRLF and lone CR are treated as line terminators inline")
    func crlfHandling() throws {
        let source = "one\r\ntwo\rthree"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let texts = dfs(doc).compactMap { $0.literal }
        // Whole input is one paragraph with softbreaks between each line.
        #expect(texts == ["one", "two", "three"])
        }
    }

    @Test("BOM is stripped at the start")
    func bomStripping() throws {
        let source = "\u{FEFF}text"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["text"])
        }
    }

    @Test("empty input yields just the document node")
    func emptyInput() throws {
        let source = ""
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document])
        }
    }

    @Test("whitespace-only input yields just the document node")
    func whitespaceOnly() throws {
        let source = "   \n\t\n   "
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document])
        }
    }
}

@Suite("Block parser - ATX headings")
struct ATXHeadingTests {

    @Test("levels 1 through 6")
    func levels() throws {
        for level in 1...6 {
            let prefix = String(repeating: "#", count: level)
            let source = "\(prefix) heading\n"
            try MarkdownDocument.withParsedDocument(source) { doc in
            let shape = dfs(doc)
            #expect(shape.count == 3, "level \(level)")
            #expect(shape[1].kind == .heading(level: level), "level \(level)")
            #expect(shape[2].literal == "heading", "level \(level)")
            }
        }
    }

    @Test("seven hashes is a paragraph, not a heading")
    func sevenHashes() throws {
        let source = "####### too many"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text])
        }
    }

    @Test("hash without trailing space is a paragraph")
    func hashWithoutSpace() throws {
        let source = "#hashtag"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text])
        }
    }

    @Test("up to 3 leading spaces still parses as heading")
    func leadingSpaces() throws {
        let source = "   ### heading"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape[1].kind == .heading(level: 3))
        #expect(shape[2].literal == "heading")
        }
    }

    @Test("4+ leading spaces is indented code, not a heading")
    func fourLeadingSpaces() throws {
        let source = "    # not a heading"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .indentedCode])
        }
    }

    @Test("trailing closing hashes are stripped")
    func closingHashes() throws {
        let source = "## heading ##\n"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["heading"])
        }
    }

    @Test("closing hashes without preceding space are part of content")
    func closingHashesNoSpace() throws {
        let source = "## foo#bar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["foo#bar"])
        }
    }

    @Test("empty heading is fine")
    func emptyHeading() throws {
        let source = "##\n"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape.count == 2) // document + heading, no text child
        #expect(shape[1].kind == .heading(level: 2))
        }
    }

    @Test("heading interrupts a paragraph")
    func interruptsParagraph() throws {
        let source = "paragraph text\n# heading\nnext paragraph"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [
            .document,
            .paragraph, .text,
            .heading(level: 1), .text,
            .paragraph, .text,
        ])
        }
    }
}

@Suite("Block parser - thematic breaks")
struct ThematicBreakTests {

    @Test("three dashes")
    func threeDashes() throws {
        let source = "---"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .thematicBreak])
        }
    }

    @Test("three asterisks")
    func threeAsterisks() throws {
        let source = "***"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .thematicBreak])
        }
    }

    @Test("three underscores")
    func threeUnderscores() throws {
        let source = "___"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .thematicBreak])
        }
    }

    @Test("more than three markers are still a single thematic break")
    func manyMarkers() throws {
        let source = "------------"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .thematicBreak])
        }
    }

    @Test("markers may be separated by spaces or tabs")
    func spacedMarkers() throws {
        let source = "- - -"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .thematicBreak])
        }
    }

    @Test("up to 3 leading spaces still parses as thematic break")
    func leadingSpaces() throws {
        let source = "   ---"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .thematicBreak])
        }
    }

    @Test("4+ leading spaces is indented code, not a thematic break")
    func fourLeadingSpaces() throws {
        let source = "    ---"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .indentedCode])
        }
    }

    @Test("only two markers is not a thematic break")
    func twoMarkers() throws {
        let source = "--"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text])
        }
    }

    @Test("mixed markers are not a thematic break")
    func mixedMarkers() throws {
        let source = "-*-"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        // The `*` delimiter run has no matching closer, so the pieces stay as text - and adjacent text is coalesced into one node (cmark's consolidate_text_nodes).
        #expect(kinds == [.document, .paragraph, .text])
        }
    }

    @Test("non-whitespace, non-marker characters disqualify the line")
    func extraCharacters() throws {
        let source = "--- and more"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text])
        }
    }

    @Test("thematic break separates paragraphs")
    func separatesParagraphs() throws {
        // A `---` on its own line (surrounded by blank lines, with no paragraph directly above) is a thematic break, not a setext H2 underline.
        let source = "before\n\n---\n\nafter"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [
            .document,
            .paragraph, .text,
            .thematicBreak,
            .paragraph, .text,
        ])
        }
    }

    @Test("consecutive thematic breaks produce multiple nodes")
    func consecutive() throws {
        let source = "---\n***\n___"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [
            .document,
            .thematicBreak,
            .thematicBreak,
            .thematicBreak,
        ])
        }
    }
}

@Suite("Block parser - setext headings")
struct SetextHeadingTests {

    @Test("equals underline produces level 1")
    func equalsIsLevel1() throws {
        let source = "Title\n====="
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape.count == 3)
        #expect(shape[1].kind == .heading(level: 1))
        #expect(shape[2].literal == "Title")
        }
    }

    @Test("dash underline produces level 2")
    func dashIsLevel2() throws {
        let source = "Title\n-----"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape.count == 3)
        #expect(shape[1].kind == .heading(level: 2))
        }
    }

    @Test("single marker character is sufficient")
    func singleMarker() throws {
        let source = "Title\n="
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape[1].kind == .heading(level: 1))
        #expect(shape[2].literal == "Title")
        }
    }

    @Test("multi-line paragraph above is all part of heading content")
    func multiLineContent() throws {
        let source = "first\nsecond\n==="
        try MarkdownDocument.withParsedDocument(source) { doc in
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["first", "second"])
        }
    }

    @Test("underline may have ≤3 leading spaces")
    func leadingSpacesOnUnderline() throws {
        let source = "Title\n   ==="
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape[1].kind == .heading(level: 1))
        }
    }

    @Test("underline with 4+ leading spaces is paragraph continuation")
    func tooManyLeadingSpaces() throws {
        let source = "Title\n    ==="
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        // Whole thing remains a paragraph; multi-line → text + softBreak + text.
        #expect(shape[1].kind == .paragraph)
        let texts = shape.compactMap { $0.literal }
        #expect(texts == ["Title", "==="])
        }
    }

    @Test("trailing spaces/tabs after the underline are allowed")
    func trailingSpaces() throws {
        let source = "Title\n===   \t  "
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(dfs(doc)[1].kind == .heading(level: 1))
        }
    }

    @Test("blank line between content and underline breaks the heading")
    func blankLineBetween() throws {
        let source = "Title\n\n==="
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        // Without paragraph open when `===` is processed, it's just paragraph text.
        #expect(kinds == [.document, .paragraph, .text, .paragraph, .text])
        }
    }

    @Test("dash underline takes precedence over thematic break when paragraph open")
    func dashOverridesThematic() throws {
        let source = "Title\n---"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        // Setext H2 - NOT thematic break.
        #expect(kinds == [.document, .heading(level: 2), .text])
        }
    }

    @Test("mixed markers on underline are not setext")
    func mixedMarkers() throws {
        let source = "Title\n=-="
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        // Falls through to paragraph continuation.
        #expect(kinds == [.document, .paragraph, .text, .softBreak, .text])
        }
    }

    @Test("setext underline is not valid with no preceding paragraph")
    func noPrecedingParagraph() throws {
        let source = "==="
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        // `=` is not a thematic break marker, so it stays a paragraph.
        #expect(kinds == [.document, .paragraph, .text])
        }
    }
}

@Suite("Block parser - indented code blocks")
struct IndentedCodeTests {

    @Test("4 spaces of indent opens an indented code block")
    func basic() throws {
        let source = "    foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape.count == 2)
        #expect(shape[1].kind.isCodeBlock)
        #expect(shape[1].literal == "foo\n")
        }
    }

    @Test("trailing newline on a code block is always present")
    func trailingNewline() throws {
        let source = "    foo\n"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape[1].literal == "foo\n")
        }
    }

    @Test("multiple indented lines join with newlines")
    func multipleLines() throws {
        let source = "    foo\n    bar\n    baz"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape[1].kind.isCodeBlock)
        #expect(shape[1].literal == "foo\nbar\nbaz\n")
        }
    }

    @Test("blank lines within indented code are preserved")
    func interiorBlankLines() throws {
        let source = "    foo\n\n    bar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape[1].kind.isCodeBlock)
        #expect(shape[1].literal == "foo\n\nbar\n")
        }
    }

    @Test("trailing blank lines are stripped from indented code")
    func trailingBlankLines() throws {
        let source = "    foo\n\n\n"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape[1].kind.isCodeBlock)
        #expect(shape[1].literal == "foo\n")
        }
    }

    @Test("non-indented non-blank line closes the code block")
    func paragraphAfter() throws {
        let source = "    code\nparagraph"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .indentedCode, .paragraph, .text])
        }
    }

    @Test("indented code cannot interrupt a paragraph")
    func cannotInterruptParagraph() throws {
        let source = "paragraph\n    not code"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text, .softBreak, .text])
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["paragraph", "not code"])
        }
    }

    @Test("more than 4 spaces - extras are part of the content")
    func extraIndent() throws {
        let source = "        deeper"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape[1].kind.isCodeBlock)
        #expect(shape[1].literal == "    deeper\n")
        }
    }

    @Test("only 3 spaces is not a code block")
    func threeSpaces() throws {
        let source = "   foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text])
        }
    }

    @Test("a four-space indent produces an indented (non-fenced) code block")
    func fourSpacesIsIndentedCodeBlock() throws {
        let source = "    let x = 1"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let shape = dfs(doc)
        #expect(shape.count == 2)
        #expect(shape[1].kind.isCodeBlock)
        #expect(shape[1].literal == "let x = 1\n")

        // The code block came from indentation, not a ``` / ~~~ fence.
        let root = doc.root
        var isFenced: Bool?
        root.children.forEach { child in
            if case .codeBlock(let info) = child.kind {
                isFenced = info.isFenced
            }
        }
        #expect(isFenced == false)
        }
    }
}

@Suite("Block parser - fenced code blocks")
struct FencedCodeTests {

    /// Helper that pulls codeBlockInfo from a MarkdownDocument's first child if it's a codeBlock.
    private static func codeInfo(_ doc: borrowing MarkdownDocument) -> (literal: String?, info: String?, fenced: Bool?) {
        var literal: String?
        var info: String?
        var fenced: Bool?
        let root = doc.root
        root.children.forEach { child in
            if case .codeBlock(let cbInfo) = child.kind {
                literal = child.literal()
                info = child.codeBlockInfoString()
                fenced = cbInfo.isFenced
            }
        }
        return (literal, info, fenced)
    }

    @Test("backtick fence")
    func backtickFence() throws {
        let source = "```\nfoo\n```"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (literal, info, fenced) = Self.codeInfo(doc)
        #expect(fenced == true)
        #expect(literal == "foo\n")
        #expect(info == "")
        }
    }

    @Test("tilde fence")
    func tildeFence() throws {
        let source = "~~~\nfoo\n~~~"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (literal, info, fenced) = Self.codeInfo(doc)
        #expect(fenced == true)
        #expect(literal == "foo\n")
        #expect(info == "")
        }
    }

    @Test("info string after backtick fence")
    func infoString() throws {
        let source = "```swift\nlet x = 1\n```"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (literal, info, _) = Self.codeInfo(doc)
        #expect(info == "swift")
        #expect(literal == "let x = 1\n")
        }
    }

    @Test("info string with trailing whitespace is trimmed")
    func infoTrimmed() throws {
        let source = "```   swift   \nbody\n```"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (_, info, _) = Self.codeInfo(doc)
        #expect(info == "swift")
        }
    }

    @Test("backtick fence info may not contain backticks")
    func backticksInInfoRejected() throws {
        // The opening fence with a backtick in its info is rejected; line is paragraph text. (A bare `` ``` `` on a later line would still start a fresh fence - that's why this test uses a single line with no follow-up.)
        let source = "```foo`bar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text])
        }
    }

    @Test("tilde fence info may contain backticks")
    func backticksInTildeInfo() throws {
        let source = "~~~ foo`bar\nbody\n~~~"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (_, info, _) = Self.codeInfo(doc)
        #expect(info == "foo`bar")
        }
    }

    @Test("4+ backticks are required to fence over a backtick info")
    func longerFence() throws {
        let source = "````\n```\n````"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (literal, _, fenced) = Self.codeInfo(doc)
        #expect(fenced == true)
        #expect(literal == "```\n")
        }
    }

    @Test("closing fence must be at least as long as opening")
    func closingFenceLength() throws {
        // Closing `` ``` `` is too short for opening ` ```` `; body continues.
        let source = "````\nfoo\n```\nbar\n````"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (literal, _, _) = Self.codeInfo(doc)
        #expect(literal == "foo\n```\nbar\n")
        }
    }

    @Test("missing closing fence is allowed (EOF closes the block)")
    func missingClosingFence() throws {
        let source = "```\nfoo\nbar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (literal, _, fenced) = Self.codeInfo(doc)
        #expect(fenced == true)
        #expect(literal == "foo\nbar\n")
        }
    }

    @Test("up to 3 leading spaces on opening fence")
    func leadingSpaces() throws {
        let source = "   ```\nfoo\n```"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .fencedCode(offset: 3)])
        }
    }

    @Test("4+ leading spaces on opening fence becomes indented code")
    func tooManyLeadingSpaces() throws {
        let source = "    ```\nfoo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (literal, _, fenced) = Self.codeInfo(doc)
        #expect(fenced == false)
        // Whole line goes in as indented code; subsequent "foo" is not in the block since it has no indent.
        #expect(literal == "```\n")
        }
    }

    @Test("empty body produces empty literal")
    func emptyBody() throws {
        let source = "```\n```"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (literal, _, fenced) = Self.codeInfo(doc)
        #expect(fenced == true)
        // Spec: empty fenced body → empty literal (renders as `<pre><code></code></pre>`).
        #expect(literal == nil || literal == "")
        }
    }

    @Test("fenced code interrupts a paragraph")
    func interruptsParagraph() throws {
        let source = "paragraph\n```\ncode\n```"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text, .fencedCode()])
        }
    }

    @Test("blank lines inside fenced code are preserved")
    func interiorBlanks() throws {
        let source = "```\nfoo\n\n\nbar\n```"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (literal, _, _) = Self.codeInfo(doc)
        #expect(literal == "foo\n\n\nbar\n")
        }
    }

    @Test("indent stripping: body lines lose up to opening-fence offset of leading space")
    func indentStripping() throws {
        let source = "  ```\n  foo\n  bar\n  ```"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let (literal, _, _) = Self.codeInfo(doc)
        #expect(literal == "foo\nbar\n")
        }
    }
}

@Suite("Block parser - block quotes")
struct BlockQuoteTests {

    @Test("single quoted line")
    func single() throws {
        let source = "> foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .blockQuote, .paragraph, .text])
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["foo"])
        }
    }

    @Test("multiple quoted lines join into one paragraph")
    func multipleLines() throws {
        let source = "> foo\n> bar\n> baz"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .blockQuote, .paragraph, .text, .softBreak, .text, .softBreak, .text])
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["foo", "bar", "baz"])
        }
    }

    @Test("optional space after `>` is consumed")
    func spaceConsumed() throws {
        let source = ">foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["foo"])
        }
    }

    @Test("up to 3 leading spaces before `>` are allowed")
    func leadingSpaces() throws {
        let source = "   > foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .blockQuote, .paragraph, .text])
        }
    }

    @Test("4+ leading spaces is indented code, not block quote")
    func fourLeadingSpaces() throws {
        let source = "    > foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .indentedCode])
        }
    }

    @Test("lazy continuation: no `>` on subsequent paragraph line")
    func lazyContinuation() throws {
        let source = "> foo\nbar\nbaz"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .blockQuote, .paragraph, .text, .softBreak, .text, .softBreak, .text])
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["foo", "bar", "baz"])
        }
    }

    @Test("thematic break interrupts a quoted paragraph and closes the quote")
    func thematicBreakInterrupts() throws {
        let source = "> foo\n---"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        // Quote with paragraph "foo", then thematic break at document level.
        #expect(kinds == [
            .document,
            .blockQuote, .paragraph, .text,
            .thematicBreak,
        ])
        }
    }

    @Test("blank line without `>` closes the quote")
    func blankClosesQuote() throws {
        let source = "> foo\n\n> bar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        // Two separate quotes.
        #expect(kinds == [
            .document,
            .blockQuote, .paragraph, .text,
            .blockQuote, .paragraph, .text,
        ])
        }
    }

    @Test("blank line with `>` keeps the quote open")
    func blankWithMarkerKeepsOpen() throws {
        let source = "> foo\n>\n> bar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        // One quote with two paragraphs.
        #expect(kinds == [
            .document,
            .blockQuote,
            .paragraph, .text,
            .paragraph, .text,
        ])
        }
    }

    @Test("nested block quotes")
    func nested() throws {
        let source = "> > foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [
            .document,
            .blockQuote,
            .blockQuote,
            .paragraph, .text,
        ])
        }
    }

    @Test("block quote can contain a heading")
    func containsHeading() throws {
        let source = "> # foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [
            .document,
            .blockQuote,
            .heading(level: 1), .text,
        ])
        }
    }

    @Test("setext heading inside a quote when underline is also quoted")
    func setextInside() throws {
        let source = "> Title\n> ---"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [
            .document,
            .blockQuote,
            .heading(level: 2), .text,
        ])
        }
    }

    @Test("block quote can contain a fenced code block")
    func containsFencedCode() throws {
        let source = "> ```\n> foo\n> ```"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .blockQuote, .fencedCode()])
        }
    }

    @Test("quote followed by separate paragraph at document level")
    func separateParagraphAfter() throws {
        let source = "> foo\n\nbar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [
            .document,
            .blockQuote, .paragraph, .text,
            .paragraph, .text,
        ])
        }
    }
}

@Suite("Block parser - lists")
struct ListTests {

    @Test("single bullet item with hyphen")
    func bulletHyphen() throws {
        let source = "- foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .bulletList(), .item(checked: nil), .paragraph, .text])
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["foo"])
        }
    }

    @Test("a block quote after list items closes the list (block quotes can't be list children)")
    func blockQuoteInterruptsList() throws {
        let source = "1. eggs\n1. milk\n> quote\n1. flour\n"
        try MarkdownDocument.withParsedDocument(source) { doc in
        // The block quote is a top-level sibling between two separate lists, not nested in the first.
        var topKinds: [MarkdownNode.Kind] = []
        let root = doc.root
        root.children.forEach { topKinds.append($0.kind) }
        #expect(topKinds == [.orderedList(), .blockQuote, .orderedList()])
        }
    }

    @Test("single bullet item with plus")
    func bulletPlus() throws {
        let source = "+ foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .bulletList(.plus), .item(checked: nil), .paragraph, .text])
        }
    }

    @Test("single bullet item with asterisk")
    func bulletAsterisk() throws {
        let source = "* foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .bulletList(.asterisk), .item(checked: nil), .paragraph, .text])
        }
    }

    @Test("ordered item with period")
    func orderedPeriod() throws {
        let source = "1. foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .orderedList(), .item(checked: nil), .paragraph, .text])
        var listKind: MarkdownNode.ListInfo.Kind?
        var listStart: Int?
        let root = doc.root
        root.children.forEach { list in
            if case .list(let info) = list.kind {
                listKind = info.kind
                listStart = info.start
            }
        }
        #expect(listKind == .ordered)
        #expect(listStart == 1)
        }
    }

    @Test("ordered item with paren")
    func orderedParen() throws {
        let source = "1) foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .orderedList(.paren), .item(checked: nil), .paragraph, .text])
        var listDelim: MarkdownNode.ListInfo.OrderedDelimiter?
        let root = doc.root
        root.children.forEach { list in
            if case .list(let info) = list.kind { listDelim = info.orderedDelimiter }
        }
        #expect(listDelim == .paren)
        }
    }

    @Test("ordered list starting at non-1")
    func orderedStart() throws {
        let source = "5. foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        var listStart: Int?
        let root = doc.root
        root.children.forEach { list in
            if case .list(let info) = list.kind { listStart = info.start }
        }
        #expect(listStart == 5)
        }
    }

    @Test("multiple bullet items in one list")
    func multipleItems() throws {
        let source = "- foo\n- bar\n- baz"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [
            .document,
            .bulletList(),
            .item(checked: nil), .paragraph, .text,
            .item(checked: nil), .paragraph, .text,
            .item(checked: nil), .paragraph, .text,
        ])
        }
    }

    @Test("bullet markers of different chars start separate lists")
    func differentMarkers() throws {
        let source = "- foo\n+ bar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [
            .document,
            .bulletList(), .item(checked: nil), .paragraph, .text,
            .bulletList(.plus), .item(checked: nil), .paragraph, .text,
        ])
        }
    }

    @Test("ordered after bullet starts new list")
    func bulletThenOrdered() throws {
        let source = "- foo\n1. bar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [
            .document,
            .bulletList(), .item(checked: nil), .paragraph, .text,
            .orderedList(), .item(checked: nil), .paragraph, .text,
        ])
        }
    }

    @Test("indented continuation line stays in the item")
    func indentedContinuation() throws {
        let source = "- foo\n  bar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        // Item with paragraph "foo" + softBreak + "bar" (continuation indented to match item padding).
        #expect(kinds == [
            .document,
            .bulletList(), .item(checked: nil), .paragraph, .text, .softBreak, .text,
        ])
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["foo", "bar"])
        }
    }

    @Test("nested list via deeper indent")
    func nested() throws {
        let source = "- a\n  - b"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        // Outer list → outer item → paragraph "a", then nested list → nested item → paragraph "b".
        #expect(kinds == [
            .document,
            .bulletList(),
            .item(checked: nil), .paragraph, .text,
            .bulletList(),
            .item(checked: nil), .paragraph, .text,
        ])
        }
    }

    @Test("`- - -` is a thematic break, not nested lists")
    func dashSpaceDashIsThematic() throws {
        let source = "- - -"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .thematicBreak])
        }
    }

    @Test("list marker without content is a valid empty item")
    func emptyItem() throws {
        let source = "-"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .bulletList(), .item(checked: nil)])
        }
    }

    @Test("list interrupts a paragraph (only when first ordered start is 1)")
    func interruptsParagraph() throws {
        let source = "paragraph\n- bullet"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [
            .document,
            .paragraph, .text,
            .bulletList(), .item(checked: nil), .paragraph, .text,
        ])
        }
    }

    @Test("ordered list with start != 1 does NOT interrupt a paragraph")
    func orderedNon1DoesNotInterrupt() throws {
        let source = "paragraph\n5. not a list"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text, .softBreak, .text])
        }
    }
}

@Suite("Block parser - HTML blocks")
struct HTMLBlockTests {

    @Test("type 1: pre tag")
    func type1Pre() throws {
        let source = "<pre>\nfoo\n</pre>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock])
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["<pre>\nfoo\n</pre>\n"])
        }
    }

    @Test("type 1: script tag, end on closing tag")
    func type1Script() throws {
        let source = "<script>\nvar x = 1;\n</script>\n\nparagraph"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock, .paragraph, .text])
        }
    }

    @Test("type 2: HTML comment")
    func type2Comment() throws {
        let source = "<!-- comment -->\nnext paragraph"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock, .paragraph, .text])
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["<!-- comment -->\n", "next paragraph"])
        }
    }

    @Test("type 2: multi-line comment")
    func type2MultilineComment() throws {
        let source = "<!--\nline 1\nline 2\n-->"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock])
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["<!--\nline 1\nline 2\n-->\n"])
        }
    }

    @Test("type 3: processing instruction")
    func type3PI() throws {
        let source = "<?php echo 1; ?>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock])
        }
    }

    @Test("type 4: declaration")
    func type4Declaration() throws {
        let source = "<!DOCTYPE html>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock])
        }
    }

    @Test("type 5: CDATA")
    func type5CDATA() throws {
        let source = "<![CDATA[\nfoo\n]]>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock])
        }
    }

    @Test("type 6: standard block tag, ends on blank line")
    func type6BlockTag() throws {
        let source = "<div>\nfoo\n</div>\n\nparagraph"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock, .paragraph, .text])
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["<div>\nfoo\n</div>\n", "paragraph"])
        }
    }

    @Test("type 6: closing tag form")
    func type6ClosingTag() throws {
        let source = "</div>\nfoo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock])
        }
    }

    @Test("type 6: self-closing form")
    func type6SelfClosing() throws {
        let source = "<hr/>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock])
        }
    }

    @Test("type 6 with up to 3 leading spaces")
    func type6LeadingSpaces() throws {
        let source = "   <div>\nbody\n</div>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock])
        }
    }

    @Test("4+ leading spaces is indented code, not HTML block")
    func tooManyLeadingSpaces() throws {
        let source = "    <div>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .indentedCode])
        }
    }

    @Test("non-block-tag like <foo> does not start a type-6 block")
    func nonBlockTagIsParagraph() throws {
        let source = "<foo>\nbar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        // With type-7 HTML block detection, `<foo>` at column 0 starts an HTML block (type 7) rather than a paragraph. The block ends on the next blank line, so `bar` is absorbed into the same block.
        #expect(kinds == [.document, .htmlBlock])
        }
    }

    @Test("HTML block interrupts a paragraph")
    func interruptsParagraph() throws {
        let source = "paragraph\n<div>\nbody\n</div>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .paragraph, .text, .htmlBlock])
        }
    }

    @Test("HTML block start and end on the same line")
    func sameLineEnd() throws {
        let source = "<!-- foo -->"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document, .htmlBlock])
        let texts = dfs(doc).compactMap { $0.literal }
        #expect(texts == ["<!-- foo -->\n"])
        }
    }
}

@Suite("Reference link definitions")
struct ReferenceDefinitionTests {

    /// Decode a `Chunk` against the document's storage/source. Adapted for tests because `MarkdownNode.url()`/`literal()` are kind-specific accessors.
    private static func decodeChunk(
        _ chunk: Chunk,
        doc: borrowing MarkdownDocument
    ) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(chunk.length)
        if chunk.inSource {
            let span = doc._source
            for i in 0..<chunk.length {
                bytes.append(span[chunk.offset + i])
            }
        } else {
            for i in 0..<chunk.length {
                bytes.append(doc._storage.strings[chunk.offset + i])
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    @Test("standalone definition produces no paragraph node")
    func standaloneDefinition() throws {
        let source = "[foo]: /url"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds == [.document])
        #expect(doc._storage.referenceMap.count == 1)
        let entry = try #require(doc._storage.referenceMap["foo"])
        #expect(Self.decodeChunk(entry.destination, doc: doc) == "/url")
        #expect(entry.title.isEmpty)
        }
    }

    @Test("definition with double-quoted title")
    func doubleQuotedTitle() throws {
        let source = "[foo]: /url \"the title\""
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(dfs(doc).map(\.kind) == [.document])
        let entry = try #require(doc._storage.referenceMap["foo"])
        #expect(Self.decodeChunk(entry.destination, doc: doc) == "/url")
        #expect(Self.decodeChunk(entry.title, doc: doc) == "the title")
        }
    }

    @Test("definition with single-quoted title")
    func singleQuotedTitle() throws {
        let source = "[foo]: /url 'the title'"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let entry = try #require(doc._storage.referenceMap["foo"])
        #expect(Self.decodeChunk(entry.title, doc: doc) == "the title")
        }
    }

    @Test("definition with paren title")
    func parenTitle() throws {
        let source = "[foo]: /url (the title)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let entry = try #require(doc._storage.referenceMap["foo"])
        #expect(Self.decodeChunk(entry.title, doc: doc) == "the title")
        }
    }

    @Test("title on next line")
    func titleOnNextLine() throws {
        let source = "[foo]: /url\n   \"the title\""
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(dfs(doc).map(\.kind) == [.document])
        let entry = try #require(doc._storage.referenceMap["foo"])
        #expect(Self.decodeChunk(entry.destination, doc: doc) == "/url")
        #expect(Self.decodeChunk(entry.title, doc: doc) == "the title")
        }
    }

    @Test("angle-bracketed destination")
    func angleBracketedDestination() throws {
        let source = "[foo]: <http://example.com/path>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let entry = try #require(doc._storage.referenceMap["foo"])
        #expect(Self.decodeChunk(entry.destination, doc: doc) == "http://example.com/path")
        }
    }

    @Test("multiple definitions in a row, no surviving paragraph")
    func multipleDefs() throws {
        let source = "[a]: /1\n[b]: /2 \"two\"\n[c]: /3"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(dfs(doc).map(\.kind) == [.document])
        #expect(doc._storage.referenceMap.count == 3)
        #expect(Self.decodeChunk(doc._storage.referenceMap["a"]!.destination, doc: doc) == "/1")
        #expect(Self.decodeChunk(doc._storage.referenceMap["b"]!.destination, doc: doc) == "/2")
        #expect(Self.decodeChunk(doc._storage.referenceMap["b"]!.title, doc: doc) == "two")
        #expect(Self.decodeChunk(doc._storage.referenceMap["c"]!.destination, doc: doc) == "/3")
        }
    }

    @Test("definition followed by paragraph content")
    func defThenParagraph() throws {
        let source = "[foo]: /url\n\nhello"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map(\.kind)
        // MarkdownDocument then a single paragraph for "hello".
        #expect(kinds == [.document, .paragraph, .text])
        #expect(doc._storage.referenceMap["foo"] != nil)
        let texts = dfs(doc).compactMap(\.literal)
        #expect(texts == ["hello"])
        }
    }

    @Test("definition then paragraph with no blank line between")
    func defThenInlineParagraph() throws {
        let source = "[foo]: /url\nhello"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map(\.kind)
        #expect(kinds == [.document, .paragraph, .text])
        #expect(doc._storage.referenceMap["foo"] != nil)
        }
    }

    @Test("first definition wins for duplicate labels")
    func duplicateLabelsFirstWins() throws {
        let source = "[foo]: /first\n[foo]: /second"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let entry = try #require(doc._storage.referenceMap["foo"])
        #expect(Self.decodeChunk(entry.destination, doc: doc) == "/first")
        }
    }

    @Test("label normalization: case-fold and collapse whitespace")
    func labelNormalization() throws {
        let source = "[Foo Bar]: /url"
        try MarkdownDocument.withParsedDocument(source) { doc in
        // Stored under normalized key.
        #expect(doc._storage.referenceMap["foo bar"] != nil)
        // Unnormalized key not present.
        #expect(doc._storage.referenceMap["Foo Bar"] == nil)
        }
    }

    @Test("invalid definition: empty label stays as paragraph")
    func invalidEmptyLabel() throws {
        let source = "[]: /url"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map(\.kind)
        #expect(kinds.contains(.paragraph))
        #expect(doc._storage.referenceMap.isEmpty)
        }
    }

    @Test("invalid definition: missing destination stays as paragraph")
    func invalidMissingDestination() throws {
        let source = "[foo]:"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map(\.kind)
        #expect(kinds.contains(.paragraph))
        #expect(doc._storage.referenceMap.isEmpty)
        }
    }

    @Test("def with title on same line but trailing junk fails the title")
    func titleWithTrailingJunk() throws {
        // Per cmark: if a title is found but the line doesn't end cleanly afterwards, the parser rewinds to the no-title commit. The dest's line must then end cleanly itself.
        let source = "[foo]: /url \"title\" extra\n\nhello"
        try MarkdownDocument.withParsedDocument(source) { doc in
        // Without title fallback, the def line "[foo]: /url \"title\" extra" doesn't end cleanly after the dest either ("\"title\" extra" is junk). So no def is registered and the whole thing is a paragraph.
        #expect(doc._storage.referenceMap["foo"] == nil)
        #expect(dfs(doc).map(\.kind).contains(.paragraph))
        }
    }
}

@Suite("GFM extensions - tasklist")
struct TasklistTests {

    /// Find the first list item and return its `isChecked` state plus the first text node's literal. Returns `(nil, nil)` if no item found.
    private static func firstItem(_ doc: borrowing MarkdownDocument) -> (checked: Bool?, text: String?) {
        var checked: Bool? = nil
        var text: String? = nil
        var found = false
        let root = doc.root
        root.children.forEach { block in
            if found { return }
            visit(block, into: &checked, &text, &found)
        }
        return (checked, text)
    }

    private static func visit(
        _ node: borrowing MarkdownNode,
        into checked: inout Bool?,
        _ text: inout String?,
        _ found: inout Bool
    ) {
        if found { return }
        if case .item(let isChecked) = node.kind {
            checked = isChecked
            collectFirstText(node, into: &text)
            found = true
            return
        }
        node.children.forEach { child in
            visit(child, into: &checked, &text, &found)
        }
    }

    private static func collectFirstText(_ node: borrowing MarkdownNode, into out: inout String?) {
        if out != nil { return }
        if let lit = node.literal() {
            out = lit
            return
        }
        node.children.forEach { child in
            collectFirstText(child, into: &out)
        }
    }

    @Test("default-disabled: [ ] stays as text in item")
    func defaultDisabled() throws {
        let source = "- [ ] foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstItem(doc)
        // `[` is a bracket, no ref-def, falls back to text - but the parser emits it as raw text. Either way isChecked should be nil.
        #expect(info.checked == nil)
        }
    }

    @Test("unchecked: - [ ] foo")
    func uncheckedItem() throws {
        let source = "- [ ] foo"
        try MarkdownDocument.withParsedDocument(source, options: .tasklist) { doc in
        let info = Self.firstItem(doc)
        #expect(info.checked == false)
        #expect(info.text == "foo")
        }
    }

    @Test("checked: - [x] foo")
    func checkedItemLowercase() throws {
        let source = "- [x] foo"
        try MarkdownDocument.withParsedDocument(source, options: .tasklist) { doc in
        let info = Self.firstItem(doc)
        #expect(info.checked == true)
        #expect(info.text == "foo")
        }
    }

    @Test("checked: - [X] foo")
    func checkedItemUppercase() throws {
        let source = "- [X] foo"
        try MarkdownDocument.withParsedDocument(source, options: .tasklist) { doc in
        let info = Self.firstItem(doc)
        #expect(info.checked == true)
        #expect(info.text == "foo")
        }
    }

    @Test("checked: ordered list 1. [x] foo")
    func checkedOrderedItem() throws {
        let source = "1. [x] foo"
        try MarkdownDocument.withParsedDocument(source, options: .tasklist) { doc in
        let info = Self.firstItem(doc)
        #expect(info.checked == true)
        }
    }

    @Test("non-marker [ y ] stays as paragraph text")
    func notATaskMarker() throws {
        let source = "- [y] foo"
        try MarkdownDocument.withParsedDocument(source, options: .tasklist) { doc in
        let info = Self.firstItem(doc)
        #expect(info.checked == nil)
        }
    }

    @Test("multiple task items in one list")
    func multipleItems() throws {
        let source = "- [ ] one\n- [x] two\n- [ ] three"
        try MarkdownDocument.withParsedDocument(source, options: .tasklist) { doc in
        var states: [Bool?] = []
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { item in
                if case .item(let checked) = item.kind {
                    states.append(checked)
                }
            }
        }
        #expect(states == [false, true, false])
        }
    }

    @Test("non-first paragraph in item is not a task marker")
    func nonFirstParagraphIsNotMarker() throws {
        // The second paragraph in the same item shouldn't be treated as a task marker even if it starts with [ ] .
        let source = "- foo\n\n  [ ] bar"
        try MarkdownDocument.withParsedDocument(source, options: .tasklist) { doc in
        let info = Self.firstItem(doc)
        // First paragraph is "foo" - no marker - item is not a task item.
        #expect(info.checked == nil)
        }
    }
}

@Suite("GFM extensions - tables")
struct TableTests {

    /// Walks the doc and pulls (kind, alignment-or-text) for the first table found. Returns rows of cells: each row is an array of `(alignment: TableAlignment?, text: String?)`.
    private static func firstTable(_ doc: borrowing MarkdownDocument) -> [[(MarkdownNode.TableAlignment?, String?)]] {
        var rows: [[(MarkdownNode.TableAlignment?, String?)]] = []
        var foundTable = false
        let root = doc.root
        root.children.forEach { block in
            if foundTable { return }
            if block.kind == .table {
                foundTable = true
                block.children.forEach { row in
                    if case .tableRow = row.kind {
                        var cells: [(MarkdownNode.TableAlignment?, String?)] = []
                        row.children.forEach { cell in
                            if case .tableCell(let alignment, _, _) = cell.kind {
                                var text: String?
                                cell.children.forEach { inline in
                                    if text == nil, let lit = inline.literal() {
                                        text = lit
                                    }
                                }
                                cells.append((alignment, text))
                            }
                        }
                        rows.append(cells)
                    }
                }
            }
        }
        return rows
    }

    @Test("default-disabled: pipe lines stay as paragraph")
    func defaultDisabled() throws {
        let source = "| a | b |\n|---|---|\n| 1 | 2 |"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = dfs(doc).map(\.kind)
        #expect(!kinds.contains(.table))
        }
    }

    @Test("simple table with delim row")
    func simpleTable() throws {
        let source = "| a | b |\n|---|---|\n| 1 | 2 |"
        try MarkdownDocument.withParsedDocument(source, options: .tables) { doc in
        let rows = Self.firstTable(doc)
        #expect(rows.count == 2)
        #expect(rows[0].map { $0.1 } == ["a", "b"])
        #expect(rows[1].map { $0.1 } == ["1", "2"])
        }
    }

    @Test("alignments: left, right, center, none")
    func alignments() throws {
        let source = "| a | b | c | d |\n|:--|---|--:|:-:|\n| 1 | 2 | 3 | 4 |"
        try MarkdownDocument.withParsedDocument(source, options: .tables) { doc in
        let rows = Self.firstTable(doc)
        let aligns = rows[0].map { $0.0 }
        let expected: [MarkdownNode.TableAlignment?] = [.left, MarkdownNode.TableAlignment.none, .right, .center]
        #expect(aligns == expected)
        }
    }

    @Test("optional outer pipes")
    func noPipesOnEnds() throws {
        let source = "a | b\n---|---\n1 | 2"
        try MarkdownDocument.withParsedDocument(source, options: .tables) { doc in
        let rows = Self.firstTable(doc)
        #expect(rows.count == 2)
        #expect(rows[0].map { $0.1 } == ["a", "b"])
        #expect(rows[1].map { $0.1 } == ["1", "2"])
        }
    }

    @Test("missing trailing cells are filled empty")
    func missingCells() throws {
        let source = "| a | b | c |\n|---|---|---|\n| 1 | 2 |"
        try MarkdownDocument.withParsedDocument(source, options: .tables) { doc in
        let rows = Self.firstTable(doc)
        #expect(rows[1].count == 3)
        #expect(rows[1].map { $0.1 } == ["1", "2", nil])
        }
    }

    @Test("extra cells are dropped")
    func extraCells() throws {
        let source = "| a | b |\n|---|---|\n| 1 | 2 | 3 | 4 |"
        try MarkdownDocument.withParsedDocument(source, options: .tables) { doc in
        let rows = Self.firstTable(doc)
        #expect(rows[1].count == 2)
        #expect(rows[1].map { $0.1 } == ["1", "2"])
        }
    }

    @Test("malformed delim row stays as paragraph")
    func malformedDelim() throws {
        let source = "| a | b |\n| not | delim |\n| 1 | 2 |"
        try MarkdownDocument.withParsedDocument(source, options: .tables) { doc in
        let kinds = dfs(doc).map(\.kind)
        #expect(!kinds.contains(.table))
        }
    }

    @Test("inline content in cells is parsed")
    func inlineInCells() throws {
        let source = "| *em* | **strong** |\n|---|---|\n| `code` | text |"
        try MarkdownDocument.withParsedDocument(source, options: .tables) { doc in
        var sawEmphasis = false
        var sawStrong = false
        var sawCode = false
        let root = doc.root
        root.children.forEach { block in
            if block.kind == .table {
                block.children.forEach { row in
                    row.children.forEach { cell in
                        cell.children.forEach { inline in
                            if inline.kind == .emphasis { sawEmphasis = true }
                            if inline.kind == .strong { sawStrong = true }
                            if case .codeInline = inline.kind { sawCode = true }
                        }
                    }
                }
            }
        }
        #expect(sawEmphasis)
        #expect(sawStrong)
        #expect(sawCode)
        }
    }

    @Test("header-only table (no body rows) is valid")
    func headerOnly() throws {
        let source = "| a | b |\n|---|---|"
        try MarkdownDocument.withParsedDocument(source, options: .tables) { doc in
        let rows = Self.firstTable(doc)
        #expect(rows.count == 1)
        #expect(rows[0].map { $0.1 } == ["a", "b"])
        }
    }

    @Test("table column count is recorded")
    func columnCount() throws {
        let source = "| a | b | c |\n|---|---|---|"
        try MarkdownDocument.withParsedDocument(source, options: .tables) { doc in
        var foundCols: Int?
        let root = doc.root
        root.children.forEach { block in
            if block.kind == .table {
                if case .table(let cols, _) = doc._storage[block._index].data {
                    foundCols = cols
                }
            }
        }
        #expect(foundCols == 3)
        }
    }
}
