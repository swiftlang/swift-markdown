/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

class AsideTests: XCTestCase {
    func testTags() {
        for kind in Aside.Kind.allCases {
            let source = "> \(kind.rawValue): This is a `\(kind.rawValue)` aside."
            let document = Document(parsing: source)
            let blockQuote = document.child(at: 0) as! BlockQuote
            let aside = Aside(blockQuote)
            XCTAssertEqual(kind, aside.kind)

            // Note that the initial text in the paragraph has been adjusted
            // to after the tag.
            let expectedRootDump = """
                Document
                └─ BlockQuote
                   └─ Paragraph
                      ├─ Text "This is a "
                      ├─ InlineCode `\(kind.rawValue)`
                      └─ Text " aside."
                """
            XCTAssertEqual(expectedRootDump, aside.content[0].root.debugDescription())
        }
    }

    func testMissingTag() {
        let source = "> This is a regular block quote."
        let document = Document(parsing: source)
        let blockQuote = document.child(at: 0) as! BlockQuote
        let aside = Aside(blockQuote)
        XCTAssertEqual(.note, aside.kind)
        XCTAssertTrue(aside.content[0].root.isIdentical(to: document))
    }

    func testUnknownTag() {
        let source = "> Hmm: This is something..."
        let document = Document(parsing: source)
        let blockQuote = document.child(at: 0) as! BlockQuote
        let aside = Aside(blockQuote)
        XCTAssertEqual(.note, aside.kind)
        XCTAssertTrue(aside.content[0].root.isIdentical(to: document))
    }

    func testNoParagraphAtStart() {
        let source = """
            > - A
            > - List?
            """
        let document = Document(parsing: source)
        let blockQuote = document.child(at: 0) as! BlockQuote
        let aside = Aside(blockQuote)
        XCTAssertEqual(.note, aside.kind)
        XCTAssertTrue(aside.content[0].root.isIdentical(to: document))
    }

    func testCaseInsensitive() {
        for kind in Aside.Kind.allCases {
            let source = "> \(kind.rawValue.lowercased()): This is a `\(kind.rawValue)` aside."
            let document = Document(parsing: source)
            let blockQuote = document.child(at: 0) as! BlockQuote
            let aside = Aside(blockQuote)
            XCTAssertEqual(kind, aside.kind)
        }
    }
}
