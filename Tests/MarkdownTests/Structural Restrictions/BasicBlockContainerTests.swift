/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class BasicBlockContainerTests: XCTestCase {
    func testFromSequence() {
        let expectedChildren = Array(repeating: Paragraph(Text("OK")), count: 3)
        let blockQuote = BlockQuote(expectedChildren)
        let gottenChildren = Array(blockQuote.children)
        XCTAssertEqual(expectedChildren.count, gottenChildren.count)
        for (expected, gotten) in zip(expectedChildren, gottenChildren) {
            XCTAssertEqual(expected.debugDescription(), gotten.detachedFromParent.debugDescription())
        }
    }
            
    func testReplacingChildrenInRange() {
        let blockQuote = BlockQuote(Array(repeating: Paragraph(Text("OK")), count: 3))
        let id = blockQuote._data.id
        
        do { // Insert one
            let insertedChild = Paragraph(Text("Inserted"))
            var newBlockQuote = blockQuote
            newBlockQuote.replaceChildrenInRange(0..<0, with: CollectionOfOne(insertedChild))
            assertElementDidntChange(blockQuote, assertedStructure: BlockQuote(Array(repeating: Paragraph(Text("OK")), count: 3)), expectedId: id)
            XCTAssertEqual(insertedChild.debugDescription(), (newBlockQuote.child(at: 0) as! Paragraph).detachedFromParent.debugDescription())
            XCTAssertEqual(4, newBlockQuote.childCount)
        }
        
        do { // Insert multiple
            let insertedChildren = Array(repeating: Paragraph(Text("Inserted")), count: 3)
            var newBlockQuote = blockQuote
            newBlockQuote.replaceChildrenInRange(0..<0, with: insertedChildren)
            assertElementDidntChange(blockQuote, assertedStructure: BlockQuote(Array(repeating: Paragraph(Text("OK")), count: 3)), expectedId: id)
            let expectedDump = """
                BlockQuote
                ├─ Paragraph
                │  └─ Text "Inserted"
                ├─ Paragraph
                │  └─ Text "Inserted"
                ├─ Paragraph
                │  └─ Text "Inserted"
                ├─ Paragraph
                │  └─ Text "OK"
                ├─ Paragraph
                │  └─ Text "OK"
                └─ Paragraph
                   └─ Text "OK"
                """
            XCTAssertEqual(expectedDump, newBlockQuote.debugDescription())
            XCTAssertEqual(6, newBlockQuote.childCount)
        }
        
        do { // Replace one
            let replacementChild = Paragraph(Text("Replacement"))
            var newBlockQuote = blockQuote
            newBlockQuote.replaceChildrenInRange(0..<1, with: CollectionOfOne(replacementChild))
            assertElementDidntChange(blockQuote, assertedStructure: BlockQuote(Array(repeating: Paragraph(Text("OK")), count: 3)), expectedId: id)
            XCTAssertEqual(replacementChild.debugDescription(), (newBlockQuote.child(at: 0) as! Paragraph).detachedFromParent.debugDescription())
            XCTAssertEqual(3, newBlockQuote.childCount)
        }
        
        do { // Replace many
            let replacementChild = Paragraph(Text("Replacement"))
            var newBlockQuote = blockQuote
            newBlockQuote.replaceChildrenInRange(0..<2, with: CollectionOfOne(replacementChild))
            assertElementDidntChange(blockQuote, assertedStructure: BlockQuote(Array(repeating: Paragraph(Text("OK")), count: 3)), expectedId: id)
            let expectedDump = """
                BlockQuote
                ├─ Paragraph
                │  └─ Text "Replacement"
                └─ Paragraph
                   └─ Text "OK"
                """
            XCTAssertEqual(expectedDump, newBlockQuote.debugDescription())
            XCTAssertEqual(2, newBlockQuote.childCount)
        }
        
        do { // Replace all
            let replacementChild = Paragraph(Text("Replacement"))
            var newBlockQuote = blockQuote
            newBlockQuote.replaceChildrenInRange(0..<3, with: CollectionOfOne(replacementChild))
            assertElementDidntChange(blockQuote, assertedStructure: BlockQuote(Array(repeating: Paragraph(Text("OK")), count: 3)), expectedId: id)
            let expectedDump = """
                BlockQuote
                └─ Paragraph
                   └─ Text "Replacement"
                """
            XCTAssertEqual(expectedDump, newBlockQuote.debugDescription())
            XCTAssertEqual(1, newBlockQuote.childCount)
        }
    }

    func testSetBlockChildren() {
        let document = Document(Paragraph(), Paragraph(), Paragraph())
        var newDocument = document
        newDocument.setBlockChildren([ThematicBreak(), ThematicBreak()])
        let expectedDump = """
            Document
            ├─ ThematicBreak
            └─ ThematicBreak
            """
        XCTAssertEqual(expectedDump, newDocument.debugDescription())
    }

    func testInheritSourceRange() throws {
        let source = "Note: This is just a paragraph."
        let fakeFileLocation = URL(fileURLWithPath: "/path/to/some-file.md")
        let document = Document(parsing: source, source: fakeFileLocation)
        let paragraph = try XCTUnwrap(document.child(at: 0) as? Paragraph)

        // this block quote has no source information, but its children do
        let blockQuote = BlockQuote(paragraph, inheritSourceRange: true)

        let expectedRootDump = """
        BlockQuote @/path/to/some-file.md:1:1-/path/to/some-file.md:1:32
        └─ Paragraph @/path/to/some-file.md:1:1-/path/to/some-file.md:1:32
           └─ Text @/path/to/some-file.md:1:1-/path/to/some-file.md:1:32 "Note: This is just a paragraph."
        """

        XCTAssertEqual(expectedRootDump, blockQuote.debugDescription(options: .printSourceLocations))
    }
}
