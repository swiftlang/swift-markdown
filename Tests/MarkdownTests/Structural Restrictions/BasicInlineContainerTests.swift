/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class BasicInlineContainerTests: XCTestCase {
    func testFromSequence() {
        let expectedChildren = Array(repeating: Text("OK"), count: 3)
        let emphasis = Emphasis(expectedChildren)
        let gottenChildren = Array(emphasis.children)
        XCTAssertEqual(expectedChildren.count, gottenChildren.count)
        for (expected, gotten) in zip(expectedChildren, gottenChildren) {
            XCTAssertEqual(expected.debugDescription(), gotten.detachedFromParent.debugDescription())
        }
    }
    
    func testReplacingChildrenInRange() {
        let emphasis = Emphasis(Array(repeating: Text("OK"), count: 3))
        let id = emphasis._data.id
        
        do { // Insert one
            let insertedChild = Text("Inserted")
            var newEmphasis = emphasis
            newEmphasis.replaceChildrenInRange(0..<0, with: CollectionOfOne(insertedChild))
            assertElementDidntChange(emphasis, assertedStructure: Emphasis(Array(repeating: Text("OK"), count: 3)), expectedId: id)
            XCTAssertEqual(insertedChild.debugDescription(), (newEmphasis.child(at: 0) as! Text).detachedFromParent.debugDescription())
            XCTAssertEqual(4, newEmphasis.childCount)
        }
        
        do { // Insert multiple
            let insertedChildren = Array(repeating: Text("Inserted"), count: 3)
            var newEmphasis = emphasis
            newEmphasis.replaceChildrenInRange(0..<0, with: insertedChildren)
            assertElementDidntChange(emphasis, assertedStructure: Emphasis(Array(repeating: Text("OK"), count: 3)), expectedId: id)
            let expectedDump = """
                Emphasis
                ├─ Text "Inserted"
                ├─ Text "Inserted"
                ├─ Text "Inserted"
                ├─ Text "OK"
                ├─ Text "OK"
                └─ Text "OK"
                """
            XCTAssertEqual(expectedDump, newEmphasis.debugDescription())
            XCTAssertEqual(6, newEmphasis.childCount)
        }
        
        do { // Replace one
            let replacementChild = Text("Replacement")
            var newEmphasis = emphasis
            newEmphasis.replaceChildrenInRange(0..<1, with: CollectionOfOne(replacementChild))
            XCTAssertEqual(replacementChild.debugDescription(), (newEmphasis.child(at: 0) as! Text).detachedFromParent.debugDescription())
            XCTAssertEqual(3, newEmphasis.childCount)
        }
        
        do { // Replace many
            let replacementChild = Text("Replacement")
            var newEmphasis = emphasis
            newEmphasis.replaceChildrenInRange(0..<2, with: CollectionOfOne(replacementChild))
            assertElementDidntChange(emphasis, assertedStructure: Emphasis(Array(repeating: Text("OK"), count: 3)), expectedId: id)
            let expectedDump = """
                Emphasis
                ├─ Text "Replacement"
                └─ Text "OK"
                """
            XCTAssertEqual(expectedDump, newEmphasis.debugDescription())
            XCTAssertEqual(2, newEmphasis.childCount)
        }
        
        do { // Replace all
            let replacementChild = Text("Replacement")
            var newEmphasis = emphasis
            newEmphasis.replaceChildrenInRange(0..<3, with: CollectionOfOne(replacementChild))
            let expectedDump = """
                Emphasis
                └─ Text "Replacement"
                """
            XCTAssertEqual(expectedDump, newEmphasis.debugDescription())
            XCTAssertEqual(1, newEmphasis.childCount)
        }
    }

    func testSetChildren() {
        let document = Paragraph(SoftBreak(), SoftBreak(), SoftBreak())
        var newDocument = document
        newDocument.setInlineChildren([Text("1"), Text("2")])
        let expectedDump = """
            Paragraph
            ├─ Text "1"
            └─ Text "2"
            """
        XCTAssertEqual(expectedDump, newDocument.debugDescription())
    }    
}

