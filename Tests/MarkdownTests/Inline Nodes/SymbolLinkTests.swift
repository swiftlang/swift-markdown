/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

class SymbolLinkTests: XCTestCase {
    func testSymbolLinkDestination() {
        let destination = "destination"
        let symbolLink = SymbolLink(destination: destination)
        XCTAssertEqual(destination, symbolLink.destination)
        XCTAssertEqual(0, symbolLink.childCount)

        let newDestination = "newdestination"
        var newSymbolLink = symbolLink
        newSymbolLink.destination = newDestination
        XCTAssertEqual(newDestination, newSymbolLink.destination)
        XCTAssertFalse(symbolLink.isIdentical(to: newSymbolLink))
    }

    func testDetectionFromInlineCode() {
        let source = "``foo()``"
        do { // option on
            let document = Document(parsing: source, options: .parseSymbolLinks)
            let expectedDump = """
                Document @1:1-1:10
                └─ Paragraph @1:1-1:10
                   └─ SymbolLink @1:1-1:10 destination: foo()
                """
            XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
        }
        do { // option off
            let document = Document(parsing: source)
            let expectedDump = """
                Document @1:1-1:10
                └─ Paragraph @1:1-1:10
                   └─ InlineCode @1:1-1:10 `foo()`
                """
            XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
        }
    }
}
