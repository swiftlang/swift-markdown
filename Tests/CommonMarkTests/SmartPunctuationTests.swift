/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

/// Tests for the `.smart` parse option, which rewrites text content during inline parsing: straight quotes become curly, `--`/`---` become en/em dashes, and `...` becomes an ellipsis.
@Suite("Parse option - smart punctuation")
struct SmartPunctuationTests {

    /// Concatenate every `.text` node's literal in document order. The smart rewrites all land in text nodes, so this reconstructs the visible string regardless of how it's split into nodes.
    private func text(_ doc: borrowing MarkdownDocument) -> String {
        var out = ""
        func walk(_ node: borrowing MarkdownNode) {
            if node.kind == .text, let literal = node.literal() {
                out += literal
            }
            node.children.forEach { walk($0) }
        }
        walk(doc.root)
        return out
    }

    /// Parse with `.smart` and return the concatenated text.
    private func smart(_ source: String) throws -> String {
        try MarkdownDocument.withParsedDocument(source, options: .smart) { doc in
        return text(doc)
        }
    }

    /// Parse without `.smart` and return the concatenated text.
    private func plain(_ source: String) throws -> String {
        try MarkdownDocument.withParsedDocument(source) { doc in
        return text(doc)
        }
    }

    // MARK: - Quotes

    @Test("double quotes become curly open/close pairs")
    func doubleQuotes() throws {
        #expect(try smart(#"He said "hello""#) == "He said \u{201C}hello\u{201D}")
    }

    @Test("single quotes become curly, including apostrophes")
    func singleQuotes() throws {
        #expect(try smart("it's a 'quote' here") == "it\u{2019}s a \u{2018}quote\u{2019} here")
    }

    @Test("an unmatched opening double quote stays a left curly quote")
    func unmatchedOpenQuote() throws {
        #expect(try smart(#""open only"#) == "\u{201C}open only")
    }

    // MARK: - Dashes

    @Test("two hyphens become an en dash, three become an em dash")
    func enAndEmDash() throws {
        #expect(try smart("foo--bar---baz") == "foo\u{2013}bar\u{2014}baz")
    }

    @Test("hyphen-run decomposition")
    func dashRuns() throws {
        #expect(try smart("a--b") == "a\u{2013}b")        // en
        #expect(try smart("a---b") == "a\u{2014}b")       // em
        #expect(try smart("a----b") == "a\u{2013}\u{2013}b")        // en en
        #expect(try smart("a-----b") == "a\u{2014}\u{2013}b")       // em en
    }

    @Test("a lone hyphen is left untouched")
    func loneHyphen() throws {
        #expect(try smart("a-b") == "a-b")
    }

    // MARK: - Ellipsis

    @Test("three dots become an ellipsis")
    func ellipsis() throws {
        #expect(try smart("wait...what") == "wait\u{2026}what")
    }

    @Test("fewer than three dots are left untouched")
    func shortDotRuns() throws {
        #expect(try smart("a.b") == "a.b")
        #expect(try smart("a..b") == "a..b")
    }

    // MARK: - Option gating

    @Test("without .smart, punctuation is left as-is")
    func smartDisabled() throws {
        #expect(try plain(#"He said "hello"--..."#) == #"He said "hello"--..."#)
    }
}
