/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import Markdown
import XCTest

class CommonMarkConverterTests: XCTestCase {
    /// Verify that a link that spans multiple lines does not crash cmark and also returns a valid range
    func testMulitlineLinks() {
        let text = """
        This is a link to an article on a different domain [link
        to an article](https://www.host.com/article).
        """
        
        let expectedDump = """
        Document @1:1-2:46
        └─ Paragraph @1:1-2:46
           ├─ Text @1:1-1:52 "This is a link to an article on a different domain "
           ├─ Link @1:52-2:45 destination: "https://www.host.com/article"
           │  ├─ Text @1:53-1:57 "link"
           │  ├─ SoftBreak
           │  └─ Text @2:1-2:14 "to an article"
           └─ Text @2:45-2:46 "."
        """
        
        let document = Document(parsing: text, source: nil, options: [.parseBlockDirectives, .parseSymbolLinks])
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }
    
    /// Verify that enabling block directive parsing does not alter the structure or source ranges of ordinary multiline links.
    func testMultilineLinksWithBlockDirectives() {
        let text =
            "This is a link to an article on a different domain [link\n" +
            "to an article](https://www.host.com/article)."

        let plain = Document(parsing: text, source: nil, options: [.parseSymbolLinks])
        let withDirectives = Document(parsing: text, source: nil, options: [.parseBlockDirectives, .parseSymbolLinks])

        XCTAssertEqual(
            plain.debugDescription(options: .printSourceLocations),
            withDirectives.debugDescription(options: .printSourceLocations),
            "BlockDirectiveParser must preserve inline children of plain paragraphs"
        )
    }
    
    /// Verify that deeply nested block and list structures preserve the  expected hierarchy and source ranges during conversion.
    func testNestedStructureRanges() {
        let text = """
        > Blockquote
        > - List item
        >   - Nested list item
        >     1. Deepest item
        """
        
        let expectedDump = """
        Document @1:1-4:22
        └─ BlockQuote @1:1-4:22
           ├─ Paragraph @1:3-1:13
           │  └─ Text @1:3-1:13 "Blockquote"
           └─ UnorderedList @2:3-4:22
              └─ ListItem @2:3-4:22
                 ├─ Paragraph @2:5-2:14
                 │  └─ Text @2:5-2:14 "List item"
                 └─ UnorderedList @3:5-4:22
                    └─ ListItem @3:5-4:22
                       ├─ Paragraph @3:7-3:23
                       │  └─ Text @3:7-3:23 "Nested list item"
                       └─ OrderedList @4:7-4:22
                          └─ ListItem @4:7-4:22
                             └─ Paragraph @4:10-4:22
                                └─ Text @4:10-4:22 "Deepest item"
        """
        
        let document = Document(parsing: text)
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    /// Verify that extremely deep nesting does not overflow the call stack during cmark-to-RawMarkup conversion.
    func testTrulyDeepNestingStackUnwind() {
        let depth = 15_000
        
        let text = String(repeating: "> ", count: depth) + "Deep"
        
        let document = Document(parsing: text)
        
        var currentNode: Markup = document
        var actualDepth = 0
        
        while let child = currentNode.child(at: 0)  {
            currentNode = child
            actualDepth += 1
        }
        
        XCTAssertGreaterThan(actualDepth, depth)
        XCTAssertEqual((currentNode as? Text)?.string, "Deep")
    }

    /// Verify that parsing an empty string produces a valid empty document.
    func testEmptyDocument() {
        let document = Document(parsing: "")
        
        let expectedDump = """
        Document
        """
        
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }
}
