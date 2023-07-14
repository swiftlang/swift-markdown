/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

class LinkTests: XCTestCase {
    func testLinkDestination() {
        let destination = "destination"
        let link = Link(destination: destination)
        XCTAssertEqual(destination, link.destination)
        XCTAssertEqual(0, link.childCount)

        let newDestination = "newdestination"
        var newLink = link
        newLink.destination = newDestination
        XCTAssertEqual(newDestination, newLink.destination)
        XCTAssertFalse(link.isIdentical(to: newLink))
    }
    
    func testLinkFromSequence() {
        let children = [Text("Hello, world!")]
        let link = Link(destination: "destination", children)
        let expectedDump = """
            Link destination: "destination"
            └─ Text "Hello, world!"
            """
        XCTAssertEqual(expectedDump, link.debugDescription())
    }
    
    func testAutoLink() {
        let children = [Text("example.com")]
        var link = Link(destination: "example.com", children)
        let expectedDump = """
            Link destination: "example.com"
            └─ Text "example.com"
            """
        XCTAssertEqual(expectedDump, link.debugDescription())
        XCTAssertTrue(link.isAutolink)
        
        link.destination = "test.example.com"
        XCTAssertFalse(link.isAutolink)
    }
    
    func testTitleLink() throws {
        let markdown = #"""
        [Example](example.com "The example title")
        [Example2](example2.com)
        [Example3]()
        """#
        
        let document = Document(parsing: markdown)
        XCTAssertEqual(document.childCount, 1)
        let paragraph = try XCTUnwrap(document.child(at: 0) as? Paragraph)
        XCTAssertEqual(paragraph.childCount, 5)

        XCTAssertTrue(paragraph.child(at: 1) is SoftBreak)
        XCTAssertTrue(paragraph.child(at: 3) is SoftBreak)
        let linkWithTitle = try XCTUnwrap(paragraph.child(at: 0) as? Link)
        let linkWithoutTitle = try XCTUnwrap(paragraph.child(at: 2) as? Link)
        let linkWithoutDestination = try XCTUnwrap(paragraph.child(at: 4) as? Link)
        
        XCTAssertEqual(try XCTUnwrap(linkWithTitle.child(at: 0) as? Text).string, "Example")
        XCTAssertEqual(linkWithTitle.destination, "example.com")
        XCTAssertEqual(linkWithTitle.title, "The example title")
        
        XCTAssertEqual(try XCTUnwrap(linkWithoutTitle.child(at: 0) as? Text).string, "Example2")
        XCTAssertEqual(linkWithoutTitle.destination, "example2.com")
        XCTAssertEqual(linkWithoutTitle.title, nil)
        
        XCTAssertEqual(try XCTUnwrap(linkWithoutDestination.child(at: 0) as? Text).string, "Example3")
        XCTAssertEqual(linkWithoutDestination.destination, nil)
        XCTAssertEqual(linkWithoutDestination.title, nil)
    }
}
