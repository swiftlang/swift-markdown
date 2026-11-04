/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

/// Walk all inline children of the first paragraph (or heading) in the document, returning a compact `(kind, literal)` list. Useful for asserting inline parser output.
internal func paragraphInlines(_ doc: borrowing MarkdownDocument) -> [(kind: MarkdownNode.Kind, literal: String?)] {
    var out: [(MarkdownNode.Kind, String?)] = []
    let root = doc.root
    root.children.forEach { block in
        if block.kind.canAccumulateText {
            block.children.forEach { inline in
                out.append((inline.kind, inline.literal()))
            }
        }
    }
    return out.map { ($0.0, $0.1) }
}

@Suite("Inline parser - code spans")
struct CodeSpanTests {

    @Test("simple single-backtick code span")
    func singleBacktick() throws {
        let source = "`foo`"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines.count == 1)
        #expect(inlines[0].kind == .codeInline(backtickCount: 1))
        #expect(inlines[0].literal == "foo")
        }
    }

    @Test("multi-backtick fence allows interior backticks")
    func multiBacktick() throws {
        let source = "``foo `bar` baz``"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines.count == 1)
        #expect(inlines[0].kind == .codeInline(backtickCount: 2))
        #expect(inlines[0].literal == "foo `bar` baz")
        }
    }

    @Test("text before and after the code span")
    func surroundingText() throws {
        let source = "foo `code` bar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        let texts = inlines.map { $0.literal }
        #expect(kinds == [.text, .codeInline(backtickCount: 1), .text])
        #expect(texts == ["foo ", "code", " bar"])
        }
    }

    @Test("unmatched opening backticks remain as text")
    func unmatchedBacktick() throws {
        let source = "`foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines.count == 1)
        #expect(inlines[0].kind == .text)
        #expect(inlines[0].literal == "`foo")
        }
    }

    @Test("mismatched fence lengths leave the line as text")
    func mismatchedLength() throws {
        let source = "`` foo `"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        // No close of length 2 → entire line stays as text.
        let kinds = inlines.map { $0.kind }
        #expect(!kinds.contains { if case .codeInline = $0 { return true } else { return false } })
        }
    }

    @Test("single space stripped from both ends when content is bracketed by spaces")
    func singleSpaceStripping() throws {
        let source = "` foo `"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].kind == .codeInline(backtickCount: 1))
        #expect(inlines[0].literal == "foo")
        }
    }

    @Test("only ONE space stripped per side")
    func oneSpacePerSide() throws {
        let source = "`  foo  `"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].kind == .codeInline(backtickCount: 1))
        #expect(inlines[0].literal == " foo ")
        }
    }

    @Test("all-space content is preserved (no stripping)")
    func allSpacesPreserved() throws {
        let source = "`  `"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].kind == .codeInline(backtickCount: 1))
        #expect(inlines[0].literal == "  ")
        }
    }

    @Test("code span with trailing space but no leading space - no stripping")
    func asymmetricSpaces() throws {
        let source = "`foo `"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].literal == "foo ")
        }
    }

    @Test("code span with three backticks each side")
    func threeBackticks() throws {
        let source = "```foo```"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].kind == .codeInline(backtickCount: 3))
        #expect(inlines[0].literal == "foo")
        }
    }

    @Test("multiple code spans in a paragraph")
    func multipleSpans() throws {
        let source = "a `b` c `d` e"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(kinds == [.text, .codeInline(backtickCount: 1), .text, .codeInline(backtickCount: 1), .text])
        }
    }

    @Test("code span inside a heading")
    func insideHeading() throws {
        let source = "# `foo` bar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].kind == .codeInline(backtickCount: 1))
        #expect(inlines[0].literal == "foo")
        #expect(inlines[1].kind == .text)
        #expect(inlines[1].literal == " bar")
        }
    }
}

@Suite("Inline parser - line breaks")
struct LineBreakTests {

    @Test("plain newline becomes a soft break")
    func softBreak() throws {
        let source = "foo\nbar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(kinds == [.text, .softBreak, .text])
        }
    }

    @Test("two trailing spaces before newline produce a hard break")
    func hardBreakSpaces() throws {
        let source = "foo  \nbar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(kinds == [.text, .lineBreak, .text])
        // The trailing spaces are stripped from the preceding text.
        #expect(inlines[0].literal == "foo")
        }
    }

    @Test("backslash before newline produces a hard break")
    func hardBreakBackslash() throws {
        let source = "foo\\\nbar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(kinds == [.text, .lineBreak, .text])
        // The trailing backslash is stripped from the preceding text.
        #expect(inlines[0].literal == "foo")
        }
    }

    @Test("single trailing space is not a hard break")
    func singleSpaceIsSoft() throws {
        let source = "foo \nbar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(kinds == [.text, .softBreak, .text])
        // The trailing space is stripped from the preceding text.
        #expect(inlines[0].literal == "foo")
        }
    }

    @Test("3+ trailing spaces still produce a hard break")
    func manySpaces() throws {
        let source = "foo   \nbar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(kinds == [.text, .lineBreak, .text])
        #expect(inlines[0].literal == "foo")
        }
    }

    @Test("multiple soft breaks in a paragraph")
    func multipleSoftBreaks() throws {
        let source = "a\nb\nc"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(kinds == [.text, .softBreak, .text, .softBreak, .text])
        }
    }

    @Test("hard and soft breaks mixed")
    func mixed() throws {
        let source = "a  \nb\nc"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(kinds == [.text, .lineBreak, .text, .softBreak, .text])
        }
    }
}

@Suite("Inline parser - HTML entities")
struct EntityTests {

    @Test("named: amp")
    func amp() throws {
        let source = "foo &amp; bar"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        // Adjacent text is coalesced into one node (cmark's consolidate_text_nodes).
        #expect(inlines.count == 1)
        #expect(inlines[0].literal == "foo & bar")
        }
    }

    @Test("named: lt and gt")
    func ltGt() throws {
        let source = "&lt;tag&gt;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let texts = inlines.compactMap { $0.literal }
        #expect(texts == ["<tag>"])
        }
    }

    @Test("named: copy → ©")
    func copyEntity() throws {
        let source = "&copy;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].literal == "©")
        }
    }

    @Test("named: hellip → …")
    func hellip() throws {
        let source = "wait&hellip;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let texts = inlines.compactMap { $0.literal }
        #expect(texts == ["wait…"])
        }
    }

    @Test("named: unknown entity stays as literal text")
    func unknownNamed() throws {
        let source = "&qwerty;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        // The whole sequence stays as one text node.
        #expect(inlines.count == 1)
        #expect(inlines[0].literal == "&qwerty;")
        }
    }

    @Test("numeric decimal")
    func numericDecimal() throws {
        let source = "&#42;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].literal == "*")
        }
    }

    @Test("numeric hex lowercase")
    func numericHexLower() throws {
        let source = "&#x2a;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].literal == "*")
        }
    }

    @Test("numeric hex uppercase X")
    func numericHexUpper() throws {
        let source = "&#X2A;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].literal == "*")
        }
    }

    @Test("numeric for non-ASCII codepoint")
    func numericNonASCII() throws {
        // &#x2026; → … (U+2026)
        let source = "&#x2026;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].literal == "…")
        }
    }

    @Test("numeric NUL is replaced with U+FFFD")
    func numericNUL() throws {
        let source = "&#0;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].literal == "\u{FFFD}")
        }
    }

    @Test("numeric out-of-range codepoint replaced with U+FFFD")
    func numericOutOfRange() throws {
        // 0x110000 is 1 above U+10FFFF (the max valid codepoint).
        let source = "&#x110000;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].literal == "\u{FFFD}")
        }
    }

    @Test("numeric with too many hex digits is not an entity")
    func numericTooManyDigits() throws {
        // 7 hex digits exceeds the spec's max of 6.
        let source = "&#x1100000;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].literal == "&#x1100000;")
        }
    }

    @Test("missing semicolon → not an entity")
    func missingSemicolon() throws {
        let source = "&amp not entity"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].literal == "&amp not entity")
        }
    }

    @Test("entity at start, middle, and end")
    func entityPositions() throws {
        let source = "&amp; mid &amp; end&amp;"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let texts = inlines.compactMap { $0.literal }
        #expect(texts == ["& mid & end&"])
        }
    }
}

@Suite("Inline parser - autolinks")
struct AutolinkTests {

    /// Pull the (kind, url, text-of-first-child) for the first link in the document's first paragraph. Returns nil for any of these if not found.
    private static func firstLink(_ doc: borrowing MarkdownDocument) -> (url: String?, text: String?) {
        var url: String?
        var text: String?
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .link {
                    url = inline.url()
                    inline.children.forEach { child in
                        if child.kind == .text, text == nil {
                            text = child.literal()
                        }
                    }
                }
            }
        }
        return (url, text)
    }

    @Test("URI autolink: http")
    func uriHTTP() throws {
        let source = "<http://example.com>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines.count == 1)
        #expect(inlines[0].kind == .link)
        let info = Self.firstLink(doc)
        #expect(info.url == "http://example.com")
        #expect(info.text == "http://example.com")
        }
    }

    @Test("URI autolink: ftp")
    func uriFTP() throws {
        let source = "<ftp://files.example.org/foo>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "ftp://files.example.org/foo")
        }
    }

    @Test("URI autolink: custom scheme")
    func customScheme() throws {
        let source = "<x-custom:bar>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "x-custom:bar")
        }
    }

    @Test("URI autolink with surrounding text")
    func surroundingText() throws {
        let source = "before <https://swift.org> after"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(kinds == [.text, .link, .text])
        }
    }

    @Test("autolink rejects whitespace in URI")
    func whitespaceRejected() throws {
        let source = "<http://example.com x>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(!kinds.contains(.link))
        }
    }

    @Test("scheme too short is not an autolink")
    func shortScheme() throws {
        let source = "<a:foo>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(!kinds.contains(.link))
        }
    }

    @Test("email autolink")
    func emailBasic() throws {
        let source = "<foo@bar.example.com>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "mailto:foo@bar.example.com")
        #expect(info.text == "foo@bar.example.com")
        }
    }

    @Test("email autolink with punctuation in local part")
    func emailWithPunct() throws {
        let source = "<f.o.o+bar@example.com>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "mailto:f.o.o+bar@example.com")
        }
    }

    @Test("email autolink with hyphen in domain")
    func emailHyphenDomain() throws {
        let source = "<a@b-c.example>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "mailto:a@b-c.example")
        }
    }

    @Test("invalid email: leading hyphen in domain label")
    func emailLeadingHyphenLabel() throws {
        let source = "<a@-bad.example>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(!kinds.contains(.link))
        }
    }

    @Test("`<` followed by non-autolink stays as text")
    func nonAutolink() throws {
        let source = "<not autolink"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        #expect(inlines[0].literal == "<not autolink")
        }
    }
}

@Suite("Inline parser - raw inline HTML")
struct InlineHTMLTests {

    /// Fetch the kind+literal of the first `.htmlInline` node in the first paragraph, or nil if none is present.
    private static func firstHTMLInline(_ doc: borrowing MarkdownDocument) -> String? {
        var out: String?
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .htmlInline, out == nil {
                    out = inline.literal()
                }
            }
        }
        return out
    }

    @Test("simple open tag")
    func simpleOpenTag() throws {
        let source = "a <b> c"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = paragraphInlines(doc).map { $0.kind }
        #expect(kinds == [.text, .htmlInline, .text])
        #expect(Self.firstHTMLInline(doc) == "<b>")
        }
    }

    @Test("open tag with attribute")
    func openTagWithAttribute() throws {
        let source = "x <a href=\"x.html\">"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstHTMLInline(doc) == "<a href=\"x.html\">")
        }
    }

    @Test("open tag with multiple attributes (single, double, unquoted)")
    func openTagMultipleAttributes() throws {
        let source = "x <input type='text' name=foo value=\"v\">"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstHTMLInline(doc) == "<input type='text' name=foo value=\"v\">")
        }
    }

    @Test("self-closing open tag")
    func selfClosingTag() throws {
        let source = "x <br />"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstHTMLInline(doc) == "<br />")
        }
    }

    @Test("close tag")
    func closeTag() throws {
        let source = "x </span>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstHTMLInline(doc) == "</span>")
        }
    }

    @Test("close tag with trailing whitespace")
    func closeTagTrailingSpaces() throws {
        let source = "x </span   >"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstHTMLInline(doc) == "</span   >")
        }
    }

    @Test("HTML comment")
    func htmlComment() throws {
        let source = "x <!-- a comment -->"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstHTMLInline(doc) == "<!-- a comment -->")
        }
    }

    @Test("empty comment <!-->")
    func emptyComment() throws {
        let source = "x <!-->"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstHTMLInline(doc) == "<!-->")
        }
    }

    @Test("near-empty comment <!--->")
    func nearEmptyComment() throws {
        let source = "x <!--->"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstHTMLInline(doc) == "<!--->")
        }
    }

    @Test("processing instruction")
    func processingInstruction() throws {
        let source = "x <?php echo 1; ?>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstHTMLInline(doc) == "<?php echo 1; ?>")
        }
    }

    @Test("declaration")
    func declaration() throws {
        let source = "x <!DOCTYPE html>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstHTMLInline(doc) == "<!DOCTYPE html>")
        }
    }

    @Test("CDATA section")
    func cdataSection() throws {
        let source = "x <![CDATA[ raw <stuff> ]]>"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstHTMLInline(doc) == "<![CDATA[ raw <stuff> ]]>")
        }
    }

    @Test("invalid: unclosed tag stays as text")
    func unclosedTag() throws {
        let source = "<a"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = paragraphInlines(doc).map { $0.kind }
        #expect(!kinds.contains(.htmlInline))
        }
    }

    @Test("invalid: unterminated comment stays as text")
    func unterminatedComment() throws {
        let source = "<!-- never closed"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = paragraphInlines(doc).map { $0.kind }
        #expect(!kinds.contains(.htmlInline))
        }
    }

    @Test("text + html + text mixes correctly")
    func mixedWithText() throws {
        let source = "before <em>x</em> after"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = paragraphInlines(doc)
        let kinds = inlines.map { $0.kind }
        #expect(kinds == [.text, .htmlInline, .text, .htmlInline, .text])
        #expect(inlines[1].literal == "<em>")
        #expect(inlines[3].literal == "</em>")
        }
    }
}

@Suite("Inline parser - emphasis / strong")
struct EmphasisTests {

    /// Render the inline tree of the first paragraph as a flat list of `(kind, literal-or-empty)` in DFS order - useful for asserting on the emphasis nesting structure produced by the delimiter stack.
    private static func dfsInlines(_ doc: borrowing MarkdownDocument) -> [(MarkdownNode.Kind, String)] {
        var out: [(MarkdownNode.Kind, String)] = []
        let root = doc.root
        root.children.forEach { block in
            if block.kind.canAccumulateText {
                visit(block, into: &out)
            }
        }
        return out
    }

    private static func visit(_ node: MarkdownNode, into out: inout [(MarkdownNode.Kind, String)]) {
        if !node.kind.canAccumulateText {
            out.append((node.kind, node.literal() ?? ""))
        }
        node.children.forEach { child in
            visit(child, into: &out)
        }
    }

    @Test("simple *emphasis*")
    func simpleStarEmph() throws {
        let source = "*foo*"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        #expect(inlines.map(\.0) == [.emphasis, .text])
        #expect(inlines[1].1 == "foo")
        }
    }

    @Test("simple _emphasis_")
    func simpleUnderEmph() throws {
        let source = "_foo_"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        #expect(inlines.map(\.0) == [.emphasis, .text])
        #expect(inlines[1].1 == "foo")
        }
    }

    @Test("simple **strong**")
    func simpleStarStrong() throws {
        let source = "**foo**"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        #expect(inlines.map(\.0) == [.strong, .text])
        #expect(inlines[1].1 == "foo")
        }
    }

    @Test("simple __strong__")
    func simpleUnderStrong() throws {
        let source = "__foo__"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        #expect(inlines.map(\.0) == [.strong, .text])
        #expect(inlines[1].1 == "foo")
        }
    }

    @Test("emphasis with surrounding text")
    func surroundingText() throws {
        let source = "a *foo* b"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        #expect(inlines.map(\.0) == [.text, .emphasis, .text, .text])
        #expect(inlines[0].1 == "a ")
        #expect(inlines[2].1 == "foo")
        #expect(inlines[3].1 == " b")
        }
    }

    @Test("nested *foo **bar** baz*")
    func nestedStrongInsideEmph() throws {
        let source = "*foo **bar** baz*"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        // emphasis containing: text "foo ", strong containing "bar", text " baz"
        let kinds = inlines.map(\.0)
        #expect(kinds == [.emphasis, .text, .strong, .text, .text])
        #expect(inlines[1].1 == "foo ")
        #expect(inlines[3].1 == "bar")
        #expect(inlines[4].1 == " baz")
        }
    }

    @Test("multiple emphasis runs in one paragraph")
    func multipleRuns() throws {
        let source = "*a* and *b*"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        #expect(inlines.map(\.0) == [.emphasis, .text, .text, .emphasis, .text])
        #expect(inlines[1].1 == "a")
        #expect(inlines[2].1 == " and ")
        #expect(inlines[4].1 == "b")
        }
    }

    @Test("intraword underscore is not emphasis")
    func intrawordUnderscore() throws {
        let source = "foo_bar_baz"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        // No .emphasis node - _bar_ is intraword and rejected.
        #expect(!inlines.map(\.0).contains(.emphasis))
        }
    }

    @Test("intraword asterisk IS emphasis")
    func intrawordAsterisk() throws {
        let source = "foo*bar*baz"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        #expect(inlines.map(\.0).contains(.emphasis))
        }
    }

    @Test("unmatched single * stays as text")
    func unmatchedStar() throws {
        let source = "*foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        #expect(!inlines.map(\.0).contains(.emphasis))
        #expect(!inlines.map(\.0).contains(.strong))
        }
    }

    @Test("asymmetric run: ***foo* bar**")
    func asymmetricStarRun() throws {
        // Per CommonMark: should produce <strong><em>foo</em> bar</strong>
        let source = "***foo* bar**"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        // strong containing: emphasis(foo), text " bar"
        #expect(inlines.map(\.0) == [.strong, .emphasis, .text, .text])
        #expect(inlines[2].1 == "foo")
        #expect(inlines[3].1 == " bar")
        }
    }

    @Test("flanking with punctuation: \"*\"foo\"*\"")
    func quotesAroundEmph() throws {
        let source = "\"*foo*\""
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        // text(`"`), emph(text(`foo`)), text(`"`)
        #expect(inlines.map(\.0) == [.text, .emphasis, .text, .text])
        }
    }

    @Test("emphasis on first byte and last byte of paragraph")
    func boundaryFlanking() throws {
        let source = "*x*"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        #expect(inlines.map(\.0) == [.emphasis, .text])
        #expect(inlines[1].1 == "x")
        }
    }

    @Test("emphasis with embedded code span")
    func emphWithCodeSpan() throws {
        let source = "*a `b` c*"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let inlines = Self.dfsInlines(doc)
        // emph: text "a ", code "b", text " c"
        #expect(inlines.map(\.0) == [.emphasis, .text, .codeInline(backtickCount: 1), .text])
        #expect(inlines[1].1 == "a ")
        #expect(inlines[2].1 == "b")
        #expect(inlines[3].1 == " c")
        }
    }
}

@Suite("Inline parser - links and images")
struct LinkImageTests {

    /// Pull (kind, url, title) for the first link/image found in DFS order, or all-nils if none.
    private static func firstLinkOrImage(
        _ doc: borrowing MarkdownDocument
    ) -> (kind: MarkdownNode.Kind, url: String?, title: String?, text: String?) {
        var result: (MarkdownNode.Kind, String?, String?, String?) = (.text, nil, nil, nil)
        var found = false
        let root = doc.root
        root.children.forEach { block in
            if found { return }
            block.children.forEach { inline in
                if found { return }
                if inline.kind == .link || inline.kind == .image {
                    var firstText: String?
                    inline.children.forEach { child in
                        if firstText == nil, let lit = child.literal() {
                            firstText = lit
                        }
                    }
                    result = (inline.kind, inline.url(), inline.title(), firstText)
                    found = true
                }
            }
        }
        return result
    }

    @Test("inline link: [text](url)")
    func inlineLink() throws {
        let source = "[foo](/url)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.kind == .link)
        #expect(info.url == "/url")
        #expect(info.title == "")
        #expect(info.text == "foo")
        }
    }

    @Test("inline link with double-quoted title")
    func inlineLinkWithTitle() throws {
        let source = "[foo](/url \"the title\")"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.url == "/url")
        #expect(info.title == "the title")
        #expect(info.text == "foo")
        }
    }

    @Test("inline link with single-quoted title")
    func inlineLinkSingleQuoted() throws {
        let source = "[foo](/url 'title')"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.title == "title")
        }
    }

    @Test("inline link with paren title")
    func inlineLinkParenTitle() throws {
        let source = "[foo](/url (title))"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.title == "title")
        }
    }

    @Test("inline link with angle-bracketed destination")
    func inlineLinkAngleBracketed() throws {
        let source = "[foo](<http://example.com/path>)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.url == "http://example.com/path")
        }
    }

    @Test("inline link with empty link text")
    func inlineLinkEmptyText() throws {
        let source = "[](/url)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.kind == .link)
        #expect(info.url == "/url")
        }
    }

    @Test("inline image: ![alt](src)")
    func inlineImage() throws {
        let source = "![alt](/img.png)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.kind == .image)
        #expect(info.url == "/img.png")
        #expect(info.text == "alt")
        }
    }

    @Test("image with title")
    func imageWithTitle() throws {
        let source = "![alt](/img.png \"caption\")"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.kind == .image)
        #expect(info.title == "caption")
        }
    }

    @Test("shortcut reference link")
    func shortcutReference() throws {
        let source = "[foo]: /url \"t\"\n\n[foo]"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.kind == .link)
        #expect(info.url == "/url")
        #expect(info.title == "t")
        #expect(info.text == "foo")
        }
    }

    @Test("collapsed reference link [foo][]")
    func collapsedReference() throws {
        let source = "[foo]: /url\n\n[foo][]"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.kind == .link)
        #expect(info.url == "/url")
        #expect(info.text == "foo")
        }
    }

    @Test("full reference link [text][label]")
    func fullReference() throws {
        let source = "[label]: /url\n\n[link text][label]"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.kind == .link)
        #expect(info.url == "/url")
        #expect(info.text == "link text")
        }
    }

    @Test("reference lookup is case-insensitive")
    func referenceCaseInsensitive() throws {
        let source = "[Foo]: /url\n\n[FOO]"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.url == "/url")
        }
    }

    @Test("unmatched [ stays as text")
    func unmatchedOpenBracket() throws {
        let source = "[foo"
        try MarkdownDocument.withParsedDocument(source) { doc in
        // No link/image; the [ remains in the inline tree as text.
        let kinds = paragraphInlines(doc).map(\.kind)
        #expect(!kinds.contains(.link))
        }
    }

    @Test("unmatched ] stays as text")
    func unmatchedCloseBracket() throws {
        let source = "foo]"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = paragraphInlines(doc).map(\.kind)
        #expect(!kinds.contains(.link))
        }
    }

    @Test("[foo] without ref-def stays as text")
    func shortcutNoMatch() throws {
        let source = "[foo]"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = paragraphInlines(doc).map(\.kind)
        #expect(!kinds.contains(.link))
        }
    }

    @Test("emphasis inside link text")
    func emphasisInsideLink() throws {
        let source = "[*foo*](/url)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLinkOrImage(doc)
        #expect(info.kind == .link)
        #expect(info.url == "/url")
        // Within the link, the text is wrapped in emphasis.
        let root = doc.root
        var foundEmph = false
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .link {
                    inline.children.forEach { child in
                        if child.kind == .emphasis {
                            foundEmph = true
                        }
                    }
                }
            }
        }
        #expect(foundEmph)
        }
    }

    @Test("link with no title, simple")
    func multipleLinks() throws {
        let source = "[a](/1) and [b](/2)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        var urls: [String] = []
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .link, let u = inline.url() {
                    urls.append(u)
                }
            }
        }
        #expect(urls == ["/1", "/2"])
        }
    }

    @Test("nested links not allowed: outer [ becomes text")
    func nestedLinksDisallowed() throws {
        let source = "[outer [inner](/i)](/o)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        // Inner link matches; outer doesn't (no_link_openers).
        var linkUrls: [String] = []
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .link, let u = inline.url() {
                    linkUrls.append(u)
                }
            }
        }
        #expect(linkUrls == ["/i"])
        }
    }

    @Test("image can contain inner link")
    func imageContainsLink() throws {
        let source = "![alt with [link](/i)](/img.png)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        // Image matches; the inner link also matches because images don't disable the link opener.
        var hasImage = false
        var hasInnerLink = false
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .image {
                    hasImage = true
                    inline.children.forEach { child in
                        if child.kind == .link {
                            hasInnerLink = true
                        }
                    }
                }
            }
        }
        #expect(hasImage)
        #expect(hasInnerLink)
        }
    }
}

@Suite("Extended attributes - `^[..]`")
struct ExtendedAttributeTests {

    /// Find the first `.attribute` node anywhere in the doc. Returns `(attrs, firstChildLiteral)` or `(nil, nil)` if none.
    private static func firstAttribute(_ doc: borrowing MarkdownDocument) -> (attrs: String?, text: String?) {
        var found: (String?, String?) = (nil, nil)
        let root = doc.root
        root.children.forEach { block in
            if found.0 != nil { return }
            block.children.forEach { inline in
                if found.0 != nil { return }
                visit(inline, into: &found)
            }
        }
        return found
    }

    private static func visit(_ node: borrowing MarkdownNode, into out: inout (String?, String?)) {
        if node.kind == .attribute, out.0 == nil {
            var firstText: String?
            node.children.forEach { child in
                if firstText == nil, let lit = child.literal() {
                    firstText = lit
                }
            }
            out = (node.attributes(), firstText)
            return
        }
        node.children.forEach { child in
            visit(child, into: &out)
        }
    }

    @Test("inline form: ^[content](attrs)")
    func inlineForm() throws {
        let source = "^[hello](color: red)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstAttribute(doc)
        #expect(info.attrs == "color: red")
        #expect(info.text == "hello")
        }
    }

    @Test("inline form: empty content")
    func emptyContent() throws {
        let source = "^[](attr)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstAttribute(doc)
        #expect(info.attrs == "attr")
        }
    }

    @Test("inline form: attrs with whitespace")
    func attrsWithWhitespace() throws {
        let source = "^[x](color: red, weight: bold)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstAttribute(doc)
        #expect(info.attrs == "color: red, weight: bold")
        }
    }

    @Test("inline form: attrs with balanced parens")
    func attrsWithParens() throws {
        let source = "^[x](rgb(255, 0, 0))"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstAttribute(doc)
        #expect(info.attrs == "rgb(255, 0, 0)")
        }
    }

    @Test("inline form: attrs with backslash-escaped paren")
    func attrsWithEscapedParen() throws {
        let source = "^[x](a\\)b)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstAttribute(doc)
        // The `\)` is an escape; cmark preserves the backslash in the chunk.
        #expect(info.attrs == "a\\)b")
        }
    }

    @Test("inline form with surrounding text")
    func surroundingText() throws {
        let source = "before ^[middle](attr) after"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstAttribute(doc)
        #expect(info.attrs == "attr")
        #expect(info.text == "middle")
        }
    }

    @Test("emphasis inside attribute content")
    func emphasisInside() throws {
        let source = "^[*foo*](attr)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        var hasEmph = false
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .attribute {
                    inline.children.forEach { child in
                        if child.kind == .emphasis { hasEmph = true }
                    }
                }
            }
        }
        #expect(hasEmph)
        }
    }

    @Test("reference def + reference form")
    func referenceForm() throws {
        let source = "^[label]: color: blue\n\n^[content][label]"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstAttribute(doc)
        #expect(info.attrs == "color: blue")
        #expect(info.text == "content")
        }
    }

    @Test("attribute ref defs do not collide with link ref defs")
    func separateRefMaps() throws {
        let source = "[foo]: /url\n^[foo]: color: red\n\n[foo] and ^[content][foo]"
        try MarkdownDocument.withParsedDocument(source) { doc in
        // Both should be registered.
        #expect(doc._storage.referenceMap["foo"] != nil)
        #expect(doc._storage.attributeReferenceMap["foo"] != nil)
        // Inline parsing should produce both a .link and a .attribute.
        var hasLink = false
        var hasAttr = false
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .link { hasLink = true }
                if inline.kind == .attribute { hasAttr = true }
            }
        }
        #expect(hasLink)
        #expect(hasAttr)
        }
    }

    @Test("invalid: ^[content] without (...) or [label] stays as text")
    func invalidNoFollowup() throws {
        let source = "^[content]"
        try MarkdownDocument.withParsedDocument(source) { doc in
        // No `.attribute` should be emitted.
        let info = Self.firstAttribute(doc)
        #expect(info.attrs == nil)
        }
    }

    @Test("invalid: unknown reference label fails")
    func invalidUnknownRef() throws {
        let source = "^[content][unknown]"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstAttribute(doc)
        #expect(info.attrs == nil)
        }
    }

    @Test("nested attribute is allowed")
    func nestedAttribute() throws {
        let source = "^[outer ^[inner](b)](a)"
        try MarkdownDocument.withParsedDocument(source) { doc in
        // Outer attribute matches; inner attribute also nests.
        var attrCount = 0
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .attribute {
                    attrCount += 1
                    inline.children.forEach { child in
                        if child.kind == .attribute {
                            attrCount += 1
                        }
                    }
                }
            }
        }
        #expect(attrCount == 2)
        }
    }
}

@Suite("GFM extensions - strikethrough")
struct StrikethroughTests {

    private static func firstStrikethrough(_ doc: borrowing MarkdownDocument) -> String? {
        var found: String?
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if found != nil { return }
                visit(inline, into: &found)
            }
        }
        return found
    }

    private static func visit(_ node: borrowing MarkdownNode, into out: inout String?) {
        if node.kind == .strikethrough, out == nil {
            var inner = ""
            node.children.forEach { child in
                if let lit = child.literal() {
                    inner += lit
                }
            }
            out = inner
            return
        }
        node.children.forEach { child in
            visit(child, into: &out)
        }
    }

    @Test("default-disabled: ~text~ stays as text")
    func defaultDisabled() throws {
        let source = "~foo~"
        try MarkdownDocument.withParsedDocument(source) { doc in
        #expect(Self.firstStrikethrough(doc) == nil)
        }
    }

    @Test("single tilde with strikethrough enabled")
    func singleTilde() throws {
        let source = "~foo~"
        try MarkdownDocument.withParsedDocument(source, options: .strikethrough) { doc in
        #expect(Self.firstStrikethrough(doc) == "foo")
        }
    }

    @Test("double tilde with strikethrough enabled")
    func doubleTilde() throws {
        let source = "~~foo~~"
        try MarkdownDocument.withParsedDocument(source, options: .strikethrough) { doc in
        #expect(Self.firstStrikethrough(doc) == "foo")
        }
    }

    @Test("strikethrough with surrounding text")
    func surroundingText() throws {
        let source = "before ~foo~ after"
        try MarkdownDocument.withParsedDocument(source, options: .strikethrough) { doc in
        #expect(Self.firstStrikethrough(doc) == "foo")
        }
    }

    @Test("doubleTilde flag rejects single tilde")
    func doubleTildeFlagRejects() throws {
        let source = "~foo~"
        try MarkdownDocument.withParsedDocument(source, options: [.strikethrough, .strikethroughDoubleTilde]) { doc in
        #expect(Self.firstStrikethrough(doc) == nil)
        }
    }

    @Test("doubleTilde flag accepts double tilde")
    func doubleTildeFlagAccepts() throws {
        let source = "~~foo~~"
        try MarkdownDocument.withParsedDocument(source, options: [.strikethrough, .strikethroughDoubleTilde]) { doc in
        #expect(Self.firstStrikethrough(doc) == "foo")
        }
    }

    @Test("mismatched tilde lengths don't pair")
    func mismatchedLengths() throws {
        let source = "~foo~~"
        try MarkdownDocument.withParsedDocument(source, options: .strikethrough) { doc in
        #expect(Self.firstStrikethrough(doc) == nil)
        }
    }

    @Test("strikethrough nested inside emphasis")
    func nestedInEmphasis() throws {
        let source = "*foo ~bar~ baz*"
        try MarkdownDocument.withParsedDocument(source, options: .strikethrough) { doc in
        // The strikethrough should be a child of the emphasis.
        var foundNested = false
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .emphasis {
                    inline.children.forEach { child in
                        if child.kind == .strikethrough {
                            foundNested = true
                        }
                    }
                }
            }
        }
        #expect(foundNested)
        }
    }
}

@Suite("GFM extensions - extended autolinks")
struct GFMAutolinkTests {

    private static func firstLink(_ doc: borrowing MarkdownDocument) -> (url: String?, text: String?) {
        var url: String?
        var text: String?
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .link, url == nil {
                    url = inline.url()
                    inline.children.forEach { child in
                        if text == nil, let lit = child.literal() {
                            text = lit
                        }
                    }
                }
            }
        }
        return (url, text)
    }

    @Test("default-disabled: bare URL stays as text")
    func defaultDisabled() throws {
        let source = "visit http://example.com today"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == nil)
        }
    }

    @Test("http URL")
    func httpURL() throws {
        let source = "visit http://example.com today"
        try MarkdownDocument.withParsedDocument(source, options: .gfmAutolink) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "http://example.com")
        #expect(info.text == "http://example.com")
        }
    }

    @Test("https URL")
    func httpsURL() throws {
        let source = "see https://example.com/path?q=1#frag"
        try MarkdownDocument.withParsedDocument(source, options: .gfmAutolink) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "https://example.com/path?q=1#frag")
        }
    }

    @Test("www URL synthesizes http://")
    func wwwURL() throws {
        let source = "go to www.example.com please"
        try MarkdownDocument.withParsedDocument(source, options: .gfmAutolink) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "http://www.example.com")
        #expect(info.text == "www.example.com")
        }
    }

    @Test("email synthesizes mailto:")
    func emailURL() throws {
        let source = "mail me at foo@example.com please"
        try MarkdownDocument.withParsedDocument(source, options: .gfmAutolink) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "mailto:foo@example.com")
        #expect(info.text == "foo@example.com")
        }
    }

    @Test("trailing punctuation is peeled")
    func trailingPunct() throws {
        let source = "see http://example.com."
        try MarkdownDocument.withParsedDocument(source, options: .gfmAutolink) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "http://example.com")
        }
    }

    @Test("trailing unbalanced ) is peeled")
    func trailingParen() throws {
        let source = "(see http://example.com/path)"
        try MarkdownDocument.withParsedDocument(source, options: .gfmAutolink) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "http://example.com/path")
        }
    }

    @Test("balanced parens within URL are kept")
    func balancedParens() throws {
        let source = "see http://en.wikipedia.org/wiki/Markdown_(format) here"
        try MarkdownDocument.withParsedDocument(source, options: .gfmAutolink) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "http://en.wikipedia.org/wiki/Markdown_(format)")
        }
    }

    @Test("URL preceded by word char is rejected")
    func wordCharBefore() throws {
        let source = "abchttp://example.com"
        try MarkdownDocument.withParsedDocument(source, options: .gfmAutolink) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == nil)
        }
    }

    @Test("URL must contain a dot in the host")
    func mustContainDot() throws {
        let source = "look at http://localhost"
        try MarkdownDocument.withParsedDocument(source, options: .gfmAutolink) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == nil)
        }
    }

    @Test("multiple URLs in one paragraph")
    func multipleURLs() throws {
        let source = "first http://a.com then https://b.com"
        try MarkdownDocument.withParsedDocument(source, options: .gfmAutolink) { doc in
        var urls: [String] = []
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if inline.kind == .link, let u = inline.url() {
                    urls.append(u)
                }
            }
        }
        #expect(urls == ["http://a.com", "https://b.com"])
        }
    }

    @Test("URL terminates at whitespace")
    func terminatesAtWhitespace() throws {
        let source = "http://a.com foo"
        try MarkdownDocument.withParsedDocument(source, options: .gfmAutolink) { doc in
        let info = Self.firstLink(doc)
        #expect(info.url == "http://a.com")
        }
    }
}

@Suite("GFM extensions - footnotes")
struct FootnoteTests {

    /// Pull the first .footnoteReference (label, index) and the first .footnoteDefinition (label, refCount) anywhere in the doc.
    private static func firstFootnotes(_ doc: borrowing MarkdownDocument) -> (
        ref: (label: String?, index: Int?)?,
        def: (label: String?, refCount: Int?)?
    ) {
        var ref: (String?, Int?)? = nil
        var def: (String?, Int?)? = nil
        let root = doc.root
        visit(root, ref: &ref, def: &def)
        return (ref, def)
    }

    private static func visit(
        _ node: borrowing MarkdownNode,
        ref: inout (String?, Int?)?,
        def: inout (String?, Int?)?
    ) {
        if case .footnoteReference(let index) = node.kind, ref == nil {
            ref = (node.footnoteLabel(), index)
        }
        if node.kind == .footnoteDefinition, def == nil {
            // refCount is internal, but we can derive it via reflection of the node's data through public API. Since there's no public accessor for refCount yet, leave it nil and verify only label.
            def = (node.footnoteLabel(), nil)
        }
        node.children.forEach { child in
            visit(child, ref: &ref, def: &def)
        }
    }

    @Test("default-disabled: [^x] stays as text")
    func defaultDisabled() throws {
        let source = "ref [^x]"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let kinds = paragraphInlines(doc).map(\.kind)
        #expect(!kinds.contains { if case .footnoteReference = $0 { true } else { false } })
        }
    }

    @Test("definition followed by reference")
    func defThenRef() throws {
        let source = "[^a]: footnote body\n\nref [^a]"
        try MarkdownDocument.withParsedDocument(source, options: .footnotes) { doc in
        let info = Self.firstFootnotes(doc)
        #expect(info.def?.label == "a")
        #expect(info.ref?.label == "a")
        #expect(info.ref?.index == 1)
        }
    }

    @Test("reference before definition still parses")
    func refThenDef() throws {
        let source = "ref [^a]\n\n[^a]: body"
        try MarkdownDocument.withParsedDocument(source, options: .footnotes) { doc in
        let info = Self.firstFootnotes(doc)
        #expect(info.ref?.label == "a")
        #expect(info.ref?.index == 1)
        #expect(info.def?.label == "a")
        }
    }

    @Test("multiple footnotes get sequential indices")
    func multipleFootnotes() throws {
        let source = "[^a] and [^b] and [^a] again"
        try MarkdownDocument.withParsedDocument(source, options: .footnotes) { doc in
        var indices: [Int] = []
        var labels: [String] = []
        let root = doc.root
        root.children.forEach { block in
            block.children.forEach { inline in
                if case .footnoteReference(let i) = inline.kind,
                   let l = inline.footnoteLabel() {
                    indices.append(i)
                    labels.append(l)
                }
            }
        }
        #expect(labels == ["a", "b", "a"])
        #expect(indices == [1, 2, 1])
        }
    }

    @Test("unresolved reference still produces a node")
    func unresolvedRef() throws {
        let source = "see [^missing]"
        try MarkdownDocument.withParsedDocument(source, options: .footnotes) { doc in
        let info = Self.firstFootnotes(doc)
        #expect(info.ref?.label == "missing")
        #expect(info.ref?.index == 1)
        }
    }

    @Test("definition produces a footnoteDefinition + paragraph child")
    func definitionStructure() throws {
        let source = "[^a]: hello world"
        try MarkdownDocument.withParsedDocument(source, options: .footnotes) { doc in
        var found = false
        let root = doc.root
        root.children.forEach { block in
            if block.kind == .footnoteDefinition {
                found = true
                var hasPara = false
                block.children.forEach { child in
                    if child.kind == .paragraph { hasPara = true }
                }
                #expect(hasPara)
            }
        }
        #expect(found)
        }
    }

    @Test("[^x] without `^` interior stays as link/text")
    func noFootnoteWithoutCaret() throws {
        // `[x]` should still try as a shortcut ref link, fail, emit `]` text.
        let source = "[x]"
        try MarkdownDocument.withParsedDocument(source, options: .footnotes) { doc in
        let kinds = paragraphInlines(doc).map(\.kind)
        #expect(!kinds.contains { if case .footnoteReference = $0 { true } else { false } })
        }
    }

    @Test("multiple definitions, multiple refs")
    func realisticDocument() throws {
        let source = """
        Some text with a ref[^one] and another[^two].

        [^one]: First note.

        [^two]: Second note.
        """
        try MarkdownDocument.withParsedDocument(source, options: .footnotes) { doc in
        var refLabels: [String] = []
        var defLabels: [String] = []
        let root = doc.root
        root.children.forEach { block in
            if block.kind == .footnoteDefinition, let l = block.footnoteLabel() {
                defLabels.append(l)
            }
            block.children.forEach { inline in
                if case .footnoteReference = inline.kind, let l = inline.footnoteLabel() {
                    refLabels.append(l)
                }
            }
        }
        #expect(refLabels == ["one", "two"])
        #expect(defLabels == ["one", "two"])
        }
    }
}
