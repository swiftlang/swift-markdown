/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
import Markdown

final class DocumentTests: XCTestCase {
    func testDocumentFromSequence() {
        let children = [
            Paragraph(Text("First")),
            Paragraph(Text("Second")),
        ]
        let document = Document(children)
        let expectedDump = """
            Document
            ├─ Paragraph
            │  └─ Text "First"
            └─ Paragraph
               └─ Text "Second"
            """
        XCTAssertEqual(expectedDump, document.debugDescription())
    }

    func testParseURL() {
        let readmeURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Block Nodes
            .appendingPathComponent("..") // MarkupTests
            .appendingPathComponent("..") // Tests
            .appendingPathComponent("..") // Project
            .appendingPathComponent("README.md")
        XCTAssertNoThrow(try Document(parsing: readmeURL))
        XCTAssertThrowsError(try Document(parsing: URL(fileURLWithPath: #file)
            .appendingPathComponent("doesntexist")))
    }
}
