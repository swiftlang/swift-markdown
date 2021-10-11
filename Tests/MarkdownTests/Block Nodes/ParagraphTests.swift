/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class ParagraphTests: XCTestCase {
    func testParagraphInserting() {
        let paragraph = Paragraph(Strong(Text("OK")))
        let id = paragraph._data.id

        do { // Insert nothing
            var newParagraph = paragraph
            newParagraph.replaceChildrenInRange(0..<0, with: [])
            assertElementDidntChange(paragraph, assertedStructure: Paragraph(Strong(Text("OK"))), expectedId: id)
            let expectedDump = """
            Paragraph
            └─ Strong
               └─ Text "OK"
            """
            XCTAssertEqual(expectedDump, newParagraph.debugDescription())
        }

        do { // Insert one
            var newParagraph = paragraph
            newParagraph.replaceChildrenInRange(0..<0, with: [InlineCode("Array")])
            assertElementDidntChange(paragraph, assertedStructure: Paragraph(Strong(Text("OK"))), expectedId: id)
            let expectedDump = """
            Paragraph
            ├─ InlineCode `Array`
            └─ Strong
               └─ Text "OK"
            """
            XCTAssertEqual(expectedDump, newParagraph.debugDescription())
        }

        do { // Insert many
            var newParagraph = paragraph
            newParagraph.replaceChildrenInRange(0..<0, with: [Text](repeating: Text("OK"), count: 5))
            assertElementDidntChange(paragraph, assertedStructure: Paragraph(Strong(Text("OK"))), expectedId: id)
            let expectedDump = """
            Paragraph
            ├─ Text "OK"
            ├─ Text "OK"
            ├─ Text "OK"
            ├─ Text "OK"
            ├─ Text "OK"
            └─ Strong
               └─ Text "OK"
            """
            XCTAssertEqual(expectedDump, newParagraph.debugDescription())
        }
    }

    func testParagraphReplacingChildrenInRange() {
        let paragraph = Paragraph(Text("1"), Text("2"), Text("3"), Text("4"))
        let id = paragraph._data.id
        do { // Replace one
            var newParagraph = paragraph
            newParagraph.replaceChildrenInRange(0..<1, with: [Text("Changed")])
            assertElementDidntChange(paragraph, assertedStructure: Paragraph(Text("1"), Text("2"), Text("3"), Text("4")), expectedId: id)
            let expectedDump = """
            Paragraph
            ├─ Text "Changed"
            ├─ Text "2"
            ├─ Text "3"
            └─ Text "4"
            """
            XCTAssertEqual(expectedDump, newParagraph.debugDescription())
        }

        do { // Replace many
            var newParagraph = paragraph
            newParagraph.replaceChildrenInRange(0..<3, with: [Text("Changed")])
            assertElementDidntChange(paragraph, assertedStructure: Paragraph(Text("1"), Text("2"), Text("3"), Text("4")), expectedId: id)
            let expectedDump = """
            Paragraph
            ├─ Text "Changed"
            └─ Text "4"
            """
            XCTAssertEqual(expectedDump, newParagraph.debugDescription())
        }

        do { // Replace all
            var newParagraph = paragraph
            newParagraph.replaceChildrenInRange(0..<4, with: [Text("Changed")])
            assertElementDidntChange(paragraph, assertedStructure: Paragraph(Text("1"), Text("2"), Text("3"), Text("4")), expectedId: id)
            let expectedDump = """
            Paragraph
            └─ Text "Changed"
            """
            XCTAssertEqual(expectedDump, newParagraph.debugDescription())
        }
    }

    func testParagraphDeleting() {
        let paragraph = Paragraph(Text("1"), Text("2"), Text("3"), Text("4"))
        let id = paragraph._data.id
        
        do { // None
            var newParagraph = paragraph
            newParagraph.replaceChildrenInRange(0..<0, with: [])
            assertElementDidntChange(paragraph, assertedStructure: Paragraph(Text("1"), Text("2"), Text("3"), Text("4")), expectedId: id)
            XCTAssertEqual(paragraph.debugDescription(), newParagraph.debugDescription())
        }

        do { // One
            var newParagraph = paragraph
            newParagraph.replaceChildrenInRange(0..<1, with: [])
            assertElementDidntChange(paragraph, assertedStructure: Paragraph(Text("1"), Text("2"), Text("3"), Text("4")), expectedId: id)
            let expectedDump = """
            Paragraph
            ├─ Text "2"
            ├─ Text "3"
            └─ Text "4"
            """
            XCTAssertEqual(expectedDump, newParagraph.debugDescription())
        }

        do { // Many
            var newParagraph = paragraph
            newParagraph.replaceChildrenInRange(0..<3, with: [])
            assertElementDidntChange(paragraph, assertedStructure: Paragraph(Text("1"), Text("2"), Text("3"), Text("4")), expectedId: id)
            let expectedDump = """
            Paragraph
            └─ Text "4"
            """
            XCTAssertEqual(expectedDump, newParagraph.debugDescription())
        }
        do { // All
            var newParagraph = paragraph
            newParagraph.replaceChildrenInRange(0..<4, with: [])
            assertElementDidntChange(paragraph, assertedStructure: Paragraph(Text("1"), Text("2"), Text("3"), Text("4")), expectedId: id)
            let expectedDump = """
            Paragraph
            """
            XCTAssertEqual(expectedDump, newParagraph.debugDescription())
        }
    }
}
