/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class HierarchyTests: XCTestCase {
    /// Tests that the actual root element is returned
    func testRoot() {
        let document = Document(parsing: "*OK*")
        let leaf = document
            .child(at: 0)!
            .child(at: 0)!
            .child(at: 0) as! Text
        XCTAssertTrue(leaf.root.isIdentical(to: document))
    }

    /// Tests that `root` returns `self` if an element is itself a root.
    func testRootSelf() {
        let paragraph = Paragraph()
        XCTAssert(paragraph.root.isIdentical(to: paragraph))
    }

    /// Tests that the spine of the tree is updated when changing a leaf.
    func testTreeAfterLeafChange() {
        let paragraph = Paragraph(Strong(Text("OK")))
        let leaf = paragraph.child(at: 0)!.child(at: 0) as! Text
        var newLeaf = leaf
        newLeaf.string = "Turned over!"

        XCTAssertFalse(newLeaf.parent!.isIdentical(to: leaf.parent!))
        XCTAssertFalse(newLeaf.parent!.parent!.isIdentical(to: leaf.parent!.parent!))

        let expectedDump = """
        Paragraph
        └─ Strong
           └─ Text "Turned over!"
        """
        XCTAssertEqual(expectedDump, newLeaf.root.debugDescription())
    }

    func testTreeAfterMiddleChange() {
        let paragraph = Paragraph(Strong(Text("Turned over!")))
        let middle = paragraph.child(at: 0) as! Strong
        let leaf = paragraph.child(at: 0)!.child(at: 0) as! Text

        var newParagraph = paragraph
        newParagraph.replaceChildrenInRange(middle.indexInParent..<middle.indexInParent + 1, with: CollectionOfOne(Emphasis(leaf)))

        XCTAssertFalse(newParagraph.isIdentical(to: paragraph))
        XCTAssertFalse(leaf.isIdentical(to: newParagraph.child(at: 0)!.child(at: 0)!))

        let expectedDump = """
        Paragraph
        └─ Emphasis
           └─ Text "Turned over!"
        """
        XCTAssertEqual(expectedDump, newParagraph.root.debugDescription())
    }
}
