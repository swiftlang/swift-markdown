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
    func testFootnotes() {
        let text = """
        text with a footnote [^1].

        [^1]: footnote definition.
        """

        let expectedDump = """
        Document @1:1-3:27
        ├─ Paragraph @1:1-1:27
        │  ├─ Text @1:1-1:22 "text with a footnote "
        │  ├─ FootnoteReference @1:22-1:26 footnoteID: `1`
        │  └─ Text @1:26-1:27 "."
        └─ FootnoteDefinition @3:7-3:27 footnoteID: `1`
           └─ Paragraph @3:7-3:27
              └─ Text @3:7-3:27 "footnote definition."
        """

        let document = Document(parsing: text, source: nil, options: [.parseBlockDirectives, .parseSymbolLinks])
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }
}
