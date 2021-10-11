/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class RawMarkupTests: XCTestCase {
    func testHasSameStructureAs() {
        do { // Identity match
            let document = RawMarkup.document(parsedRange: nil, [])
            XCTAssert(document.hasSameStructure(as: document))
        }

        do { // Empty match
            XCTAssert(RawMarkup.document(parsedRange: nil, []).hasSameStructure(as: .document(parsedRange: nil, [])))
        }

        do { // Same child count, but different structure
            let document1 = RawMarkup.document(parsedRange: nil, [.paragraph(parsedRange: nil, [])])
            let document2 = RawMarkup.document(parsedRange: nil, [.thematicBreak(parsedRange: nil)])
            XCTAssertFalse(document1.hasSameStructure(as: document2))
        }

        do { // Different child count
            let document1 = RawMarkup.document(parsedRange: nil, [.paragraph(parsedRange: nil, [])])
            let document2 = RawMarkup.document(parsedRange: nil, [.paragraph(parsedRange: nil, []), .thematicBreak(parsedRange: nil)])
            XCTAssertFalse(document1.hasSameStructure(as: document2))
        }

        do { // Same child count, different structure, nested
            let document1 = RawMarkup.document(parsedRange: nil, [
                .paragraph(parsedRange: nil, [
                    .text(parsedRange: nil, string: "Hello")
                ]),
                .paragraph(parsedRange: nil, [
                    .text(parsedRange: nil, string: "World")
                ]),
            ])
            let document2 = RawMarkup.document(parsedRange: nil, [
                .paragraph(parsedRange: nil, [
                    .text(parsedRange: nil, string: "Hello"),
                ]),
                .paragraph(parsedRange: nil, [
                    .emphasis(parsedRange: nil, [
                        .text(parsedRange: nil, string: "World"),
                    ]),
                ]),
            ])
            XCTAssertFalse(document1.hasSameStructure(as: document2))
        }
    }

    /// When an element changes a child, unchanged children should use the same `RawMarkup` as before.
    func testSharing() {
        let originalRoot = Document(
            Paragraph(Text("ChangeMe")),
            Paragraph(Text("Unchanged")))

        let firstText = originalRoot.child(through: [
            0, // Paragraph
            0, // Text
        ]) as! Text

        var newText = firstText
        newText.string = "Changed"
        let newRoot = newText.root

        XCTAssertFalse(originalRoot.child(at: 0)!.raw.markup === newRoot.child(at: 0)!.raw.markup)
        XCTAssertTrue(originalRoot.child(at: 1)!.raw.markup === newRoot.child(at: 1)!.raw.markup)
    }
}
