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

    /// Test using a custom set of Commonmark options to convert Markdown.
    func testCustomOpts() {
        let text = "~This is not strikethrough~ -- but ~~this is strikethrough~~."

        // Because the "smart" option is not set, the `--` should not be converted
        // to an en-dash.
        let expectedDump = """
        Document @1:1-1:62
        └─ Paragraph @1:1-1:62
           ├─ Text @1:1-1:36 "~This is not strikethrough~ -- but "
           ├─ Strikethrough @1:36-1:61
           │  └─ Text @1:38-1:59 "this is strikethrough"
           └─ Text @1:61-1:62 "."
        """

        let document = Document(
            parsing: text,
            source: nil,
            convertOptions: .init(
                parseOptions: ConvertOptions.defaultParseOptions,
                commonmarkOptions: .strikethroughDoubleTilde,
                extensions: ConvertOptions.defaultCommonmarkExtensions
            )
        )
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }
}
