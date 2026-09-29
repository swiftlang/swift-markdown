/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

@Suite("BasicTests")
struct BasicTests {

    @Test("empty document parses to a single .document node with no children")
    func emptyDocument() throws {
        let source = ""
        try MarkdownDocument.withParsedDocument(source) { doc in
        let root = doc.root
        let kind = root.kind
        let isLeaf = root.isLeaf
        var count = 0
        root.children.forEach { _ in
            count += 1
        }

        #expect(kind == .document)
        #expect(isLeaf)
        #expect(count == 0)
        }
    }

    @Test("non-empty source produces stub paragraph + text (placeholder behavior)")
    func stubParagraph() throws {
        let source = "hello"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let root = doc.root
        let rootKind = root.kind

        var visited: [MarkdownNode.Kind] = []
        var textLiteral: String?
        root.children.forEach { paragraph in
            visited.append(paragraph.kind)
            paragraph.children.forEach { inline in
                visited.append(inline.kind)
                if inline.kind == .text {
                    textLiteral = inline.literal()
                }
            }
        }

        #expect(rootKind == .document)
        #expect(visited == [.paragraph, .text])
        #expect(textLiteral == "hello")
        }
    }

    @Test("parent/sibling navigation links work")
    func navigation() throws {
        let source = "abc"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let root = doc.root

        var paragraphParentKind: MarkdownNode.Kind?
        var textParentKind: MarkdownNode.Kind?
        var textHasNext = true
        var textHasPrev = true

        root.children.forEach { paragraph in
            if let parent = paragraph.parent {
                paragraphParentKind = parent.kind
            }
            paragraph.children.forEach { text in
                if let parent = text.parent {
                    textParentKind = parent.kind
                }
                textHasNext = text.next != nil
                textHasPrev = text.previous != nil
            }
        }

        #expect(paragraphParentKind == .document)
        #expect(textParentKind == .paragraph)
        #expect(!textHasNext)
        #expect(!textHasPrev)
        }
    }

    @Test("MarkdownNode.Kind classifies block vs. inline correctly")
    func kindClassification() {
        #expect(MarkdownNode.Kind.document.isBlock)
        #expect(MarkdownNode.Kind.paragraph.isBlock)
        #expect(MarkdownNode.Kind.heading(level: 1).isBlock)
        #expect(MarkdownNode.Kind.table.isBlock)
        #expect(MarkdownNode.Kind.text.isInline)
        #expect(MarkdownNode.Kind.emphasis.isInline)
        #expect(MarkdownNode.Kind.attribute.isInline)
        #expect(MarkdownNode.Kind.strikethrough.isInline)
    }

    @Test("options are exposed on the parsed document")
    func optionsRoundTrip() throws {
        let source = "x"
        try MarkdownDocument.withParsedDocument(source, options: [.smart, .footnotes]) { doc in
        let opts = doc.options
        #expect(opts.contains(.smart))
        #expect(opts.contains(.footnotes))
        #expect(!opts.contains(.strikethrough))
        }
    }
    
    @Test("reasonably sized markdown document example - performance")
    func performanceExample() throws {
        // This is the basic markdown doc from the performance tests. We have a test here that parses it as well, for easy debugging when looking into performance improvements.
        let sample = """
        # Hello, World

        This is a *simple* markdown document with some **bold** text, a [link](https://example.com), and a code span: `let x = 1`.

        - First item
        - Second item
        - Third item
        """

        try MarkdownDocument.withParsedDocument(sample) { document in
        #expect(document.root.kind == .document)
        }
    }
}
