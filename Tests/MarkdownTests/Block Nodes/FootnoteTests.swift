/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import Markdown
import XCTest

class FootnoteTests: XCTestCase {
    func testSimpleFootnote() {
        let source = """
        text with a footnote [^1].
        [^1]: footnote definition.
        """

        let document = Document(parsing: source)

        let expectedDump = """
        Document @1:1-2:27
        ├─ Paragraph @1:1-1:27
        │  ├─ Text @1:1-1:22 "text with a footnote "
        │  ├─ FootnoteReference @1:22-1:26 footnoteID: `1`
        │  └─ Text @1:26-1:27 "."
        └─ FootnoteDefinition @2:7-2:27 footnoteID: `1`
           └─ Paragraph @2:7-2:27
              └─ Text @2:7-2:27 "footnote definition."
        """

        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    func testBlockFootnote() {
        let source = """
        text with a block footnote [^1].
        [^1]: This is a long footnote, including a quote:

            > This is a multi-line quote, spanning
            > multiple lines.

            And then some more text.
        """

        let document = Document(parsing: source)

        let expectedDump = """
        Document @1:1-7:29
        ├─ Paragraph @1:1-1:33
        │  ├─ Text @1:1-1:28 "text with a block footnote "
        │  ├─ FootnoteReference @1:28-1:32 footnoteID: `1`
        │  └─ Text @1:32-1:33 "."
        └─ FootnoteDefinition @2:7-7:29 footnoteID: `1`
           ├─ Paragraph @2:7-2:50
           │  └─ Text @2:7-2:50 "This is a long footnote, including a quote:"
           ├─ BlockQuote @4:5-5:22
           │  └─ Paragraph @4:7-5:22
           │     ├─ Text @4:7-4:43 "This is a multi-line quote, spanning"
           │     ├─ SoftBreak
           │     └─ Text @5:7-5:22 "multiple lines."
           └─ Paragraph @7:5-7:29
              └─ Text @7:5-7:29 "And then some more text."
        """

        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }
  }
