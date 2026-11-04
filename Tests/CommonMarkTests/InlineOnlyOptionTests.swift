/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

/// Tests for the extended parse options `.inlineOnly` and `.preserveWhitespace`.
///
/// Ground-truth behavior at the parser / AST level:
///  - No block containers are ever opened. The entire input collapses into a *single* `.paragraph`. Markers like `#`, `* `, `> `, `---`, ` ``` ` and 4-space indents stay literal text rather than producing headings / lists / quotes / thematic breaks / code blocks.
///  - Inline syntax is still parsed (emphasis, code spans, links, …).
///  - Newlines between source lines (including blank lines) are preserved verbatim inside the paragraph's text rather than splitting it or becoming soft breaks.
///  - Leading and trailing whitespace is preserved.
///  - At the parser level `.inlineOnly` and `.preserveWhitespace` produce an identical tree; the whitespace *collapsing* that distinguishes Foundation's two modes happens in a higher rendering layer, not in the parser.
@Suite("Parse options - inlineOnly / preserveWhitespace")
struct InlineOnlyOptionTests {

    /// The single top-level child of the document, or `nil` if the count isn't exactly one.
    private func soleBlock(_ doc: borrowing MarkdownDocument) -> (kind: MarkdownNode.Kind, count: Int)? {
        var kinds: [MarkdownNode.Kind] = []
        let root = doc.root
        root.children.forEach { kinds.append($0.kind) }
        guard kinds.count == 1 else { return (kinds.first ?? .document, kinds.count) }
        return (kinds[0], 1)
    }

    /// `(kind, literal)` for every inline child of the document's first paragraph.
    private func inlines(_ doc: borrowing MarkdownDocument) -> [(kind: MarkdownNode.Kind, literal: String?)] {
        paragraphInlines(doc).map { ($0.kind, $0.literal) }
    }

    /// A compact recursive dump of the whole tree - used to compare two parses for AST equality.
    private func dump(_ doc: borrowing MarkdownDocument) -> String {
        var out = ""
        func walk(_ node: borrowing MarkdownNode, _ depth: Int) {
            out += String(repeating: "  ", count: depth)
            out += "\(node.kind)"
            if let literal = node.literal() { out += " \(String(reflecting: literal))" }
            if let url = node.url() { out += " url=\(url)" }
            out += "\n"
            node.children.forEach { walk($0, depth + 1) }
        }
        let root = doc.root
        walk(root, 0)
        return out
    }

    // MARK: - inlineOnly

    @Test("inlineOnly suppresses all block structure into one paragraph")
    func inlineOnlySuppressesBlocks() throws {
        let source = "# heading\n\n* item"
        try MarkdownDocument.withParsedDocument(source, options: .inlineOnly) { doc in

        let block = soleBlock(doc)
        #expect(block?.kind == .paragraph)
        #expect(block?.count == 1)

        // The `#` and `* ` markers stay literal, and the blank line is kept as `\n\n`.
        let inlines = inlines(doc)
        #expect(inlines.map(\.kind) == [.text])
        #expect(inlines.first?.literal == "# heading\n\n* item")
        }
    }

    @Test("inlineOnly still parses inline emphasis and code spans")
    func inlineOnlyKeepsInlineSyntax() throws {
        let source = "# *em* and `code`"
        try MarkdownDocument.withParsedDocument(source, options: .inlineOnly) { doc in

        #expect(soleBlock(doc)?.kind == .paragraph)

        let inlines = inlines(doc)
        #expect(inlines.map(\.kind) == [.text, .emphasis, .text, .codeInline(backtickCount: 1)])
        #expect(inlines.map(\.literal) == ["# ", nil, " and ", "code"])

        // The emphasis wraps a `text` node carrying its content.
        var emphasisText: String?
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .emphasis {
                    inline.children.forEach { emphasisText = $0.literal() }
                }
            }
        }
        #expect(emphasisText == "em")
        }
    }

    @Test("inlineOnly still parses links")
    func inlineOnlyParsesLinks() throws {
        let source = "see [text](http://example.com) ok"
        try MarkdownDocument.withParsedDocument(source, options: .inlineOnly) { doc in

        #expect(soleBlock(doc)?.kind == .paragraph)

        let inlines = inlines(doc)
        #expect(inlines.map(\.kind) == [.text, .link, .text])
        #expect(inlines.map(\.literal) == ["see ", nil, " ok"])

        var linkURL: String?
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .link { linkURL = inline.url() }
            }
        }
        #expect(linkURL == "http://example.com")
        }
    }

    @Test("inlineOnly does not turn a 4-space indent into a code block")
    func inlineOnlyNoIndentedCodeBlock() throws {
        let source = "    indented code"
        try MarkdownDocument.withParsedDocument(source, options: .inlineOnly) { doc in

        // A normal parse would make this a `.codeBlock`; inline-only keeps the leading spaces as literal paragraph text.
        #expect(soleBlock(doc)?.kind == .paragraph)
        let inlines = inlines(doc)
        #expect(inlines.map(\.kind) == [.text])
        #expect(inlines.first?.literal == "    indented code")
        }
    }

    @Test("inlineOnly leaves a blockquote marker as literal text")
    func inlineOnlyNoBlockQuote() throws {
        let source = "> not a quote"
        try MarkdownDocument.withParsedDocument(source, options: .inlineOnly) { doc in

        #expect(soleBlock(doc)?.kind == .paragraph)
        #expect(inlines(doc).first?.literal == "> not a quote")
        }
    }

    // MARK: - preserveWhitespace

    @Test("preserveWhitespace is a superset that includes inlineOnly")
    func preserveWhitespaceImpliesInlineOnly() {
        // Pure option-set composition - independent of the parser implementation.
        #expect(MarkdownDocument.ParseOptions.preserveWhitespace.contains(.inlineOnly))
    }

    @Test("preserveWhitespace keeps leading/trailing whitespace and blank lines")
    func preserveWhitespaceKeepsWhitespace() throws {
        let source = "   leading   spaces\n\n\ntrailing  "
        try MarkdownDocument.withParsedDocument(source, options: .preserveWhitespace) { doc in

        let block = soleBlock(doc)
        #expect(block?.kind == .paragraph)
        #expect(block?.count == 1)

        // Leading indent, the run of interior spaces, the blank lines, and the trailing spaces all survive verbatim in a single text node.
        let inlines = inlines(doc)
        #expect(inlines.map(\.kind) == [.text])
        #expect(inlines.first?.literal == "   leading   spaces\n\n\ntrailing  ")
        }
    }

    @Test("preserveWhitespace and inlineOnly produce an identical parser AST")
    func preserveWhitespaceMatchesInlineOnlyAST() throws {
        // The whitespace-collapsing that distinguishes Foundation's two interpreted-syntax modes happens above the parser; at the AST level the two options are equivalent.
        let source = "  # x\n\n  *y*  \n\n> z"
        try MarkdownDocument.withParsedDocument(source, options: .inlineOnly) { inlineOnly in
            try MarkdownDocument.withParsedDocument(source, options: .preserveWhitespace) { preserve in
                #expect(dump(inlineOnly) == dump(preserve))
            }
        }
    }
}
