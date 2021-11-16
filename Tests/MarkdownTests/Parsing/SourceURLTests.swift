/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import XCTest

/// Checks that each element visited has
struct CheckAllElementsHaveSourceLocationURL: MarkupWalker {
    let source: URL
    func defaultVisit(_ markup: Markup) {
        XCTAssertEqual(source, markup.range?.lowerBound.source)
    }
}

class SourceURLTests: XCTestCase {
    func testParseStringURLSource() {
        let text = """
        This is a paragraph.

        - A
        - B
          - C

        > Quote
        > Quote

        ``foo()``

        @Outer {
          @Inner

          - A
        }
        """
        let source = URL(string: "https://swift.org/test.md")!
        let document = Document(parsing: text, source: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        var checker = CheckAllElementsHaveSourceLocationURL(source: source)
        checker.visit(document)

        let expectedDump = """
        Document @/test.md:1:1-/test.md:16:2
        ├─ Paragraph @/test.md:1:1-/test.md:1:21
        │  └─ Text @/test.md:1:1-/test.md:1:21 "This is a paragraph."
        ├─ UnorderedList @/test.md:3:1-/test.md:6:1
        │  ├─ ListItem @/test.md:3:1-/test.md:3:4
        │  │  └─ Paragraph @/test.md:3:3-/test.md:3:4
        │  │     └─ Text @/test.md:3:3-/test.md:3:4 "A"
        │  └─ ListItem @/test.md:4:1-/test.md:6:1
        │     ├─ Paragraph @/test.md:4:3-/test.md:4:4
        │     │  └─ Text @/test.md:4:3-/test.md:4:4 "B"
        │     └─ UnorderedList @/test.md:5:3-/test.md:6:1
        │        └─ ListItem @/test.md:5:3-/test.md:6:1
        │           └─ Paragraph @/test.md:5:5-/test.md:5:6
        │              └─ Text @/test.md:5:5-/test.md:5:6 "C"
        ├─ BlockQuote @/test.md:7:1-/test.md:8:8
        │  └─ Paragraph @/test.md:7:3-/test.md:8:8
        │     ├─ Text @/test.md:7:3-/test.md:7:8 "Quote"
        │     ├─ SoftBreak
        │     └─ Text @/test.md:8:3-/test.md:8:8 "Quote"
        ├─ Paragraph @/test.md:10:1-/test.md:10:10
        │  └─ SymbolLink @/test.md:10:1-/test.md:10:10 destination: foo()
        └─ BlockDirective @/test.md:12:1-/test.md:16:2 name: "Outer"
           ├─ BlockDirective @/test.md:13:3-/test.md:13:9 name: "Inner"
           └─ UnorderedList @/test.md:15:3-/test.md:15:6
              └─ ListItem @/test.md:15:3-/test.md:15:6
                 └─ Paragraph @/test.md:15:5-/test.md:15:6
                    └─ Text @/test.md:15:5-/test.md:15:6 "A"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }
}
