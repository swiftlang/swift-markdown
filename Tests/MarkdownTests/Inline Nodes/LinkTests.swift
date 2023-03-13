/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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
}
