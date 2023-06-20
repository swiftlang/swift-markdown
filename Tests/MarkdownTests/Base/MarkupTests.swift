/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

/// Tests public API of `Markup`.
final class MarkupTests: XCTestCase {
    func testRangeUnparsed() {
        let document = Document(Paragraph(Strong(Text("OK"))))
        XCTAssertNil(document.range)

        let paragraph = document.child(at: 0) as! Paragraph
        XCTAssertNil(paragraph.range)

        let strong = paragraph.child(at: 0) as! Strong
        XCTAssertNil(strong.range)

        let text = strong.child(at: 0) as! Text
        XCTAssertNil(text.range)
    }

    func testRangeParsed() {
        let source = "**OK**"

        let document = Document(parsing: source)
        XCTAssertEqual(SourceLocation(line: 1, column: 1, source: nil)..<SourceLocation(line: 1, column: 7, source: nil),
                       document.range)

        let paragraph = document.child(at: 0) as! Paragraph
        XCTAssertEqual(SourceLocation(line: 1, column: 1, source: nil)..<SourceLocation(line: 1, column: 7, source: nil),
                       paragraph.range)

        let strong = paragraph.child(at: 0) as! Strong
        XCTAssertEqual(SourceLocation(line: 1, column: 1, source: nil)..<SourceLocation(line: 1, column: 7, source: nil),
                       strong.range)

        let text = strong.child(at: 0) as! Text
        XCTAssertEqual(SourceLocation(line: 1, column: 3, source: nil)..<SourceLocation(line: 1, column: 5, source: nil),
                       text.range)
    }

    /// Because markup trees aren't "full fidelity" (e.g. block quote markers
    /// nor indentation is tracked), modifying a tree should destroy what limited
    /// source range mapping was provided by cmark.
    func testRangesRemovedOnModify() {
        let source = "***OK***"
        let document = Document(parsing: source)

        struct AssertRangesPresent: MarkupWalker {
            mutating func defaultVisit(_ markup: Markup) {
                XCTAssertNotNil(markup.range)
                descendInto(markup)
            }
        }

        var rangesPresent = AssertRangesPresent()
        rangesPresent.visit(document)

        struct AssertRangesNotPresent: MarkupWalker {
            mutating func defaultVisit(_ markup: Markup) {
                XCTAssertNil(markup.range)
                descendInto(markup)
            }
        }

        let text = document.child(through: [
          0, // Paragraph
          0, // Strong
          0, // Emphasis
          0,
        ]) as! Text
        var newText = text
        newText.string = "New"

        var rangesNotPresent = AssertRangesNotPresent()
        rangesNotPresent.visit(newText.root)
    }

    func testRoot() {
        let document = Document(Paragraph(Strong(Text("OK"))))
        let leaf = document
            .child(at: 0)!
            .child(at: 0)!
            .child(at: 0)! as! Text
        XCTAssertTrue(document.isIdentical(to: leaf.root))
    }

    /// Test that a detached node still maintains range mapping.
    func testDetachedFromParent() {
        let document = Document(parsing: "***OK***")
        XCTAssertTrue(document.detachedFromParent.isIdentical(to: document))

        let paragraph = document.child(at: 0) as! Paragraph
        let emphasis = paragraph.child(at: 0) as! Emphasis
        let strong = emphasis.child(at: 0) as! Strong
        let text = strong.child(at: 0) as! Text

        let detachedParagraph = paragraph.detachedFromParent
        XCTAssertNotEqual(paragraph._data.id.rootId, detachedParagraph._data.id.rootId)
        XCTAssertEqual(0, detachedParagraph._data.id.childId)
        let newEmphasis = detachedParagraph.child(at: 0) as! Emphasis
        let newStrong = newEmphasis.child(at: 0) as! Strong
        let newText = newStrong.child(at: 0) as! Text

        XCTAssertEqual(paragraph.range, detachedParagraph.range)
        XCTAssertEqual(strong.range, newStrong.range)
        XCTAssertEqual(emphasis.range, newEmphasis.range)
        XCTAssertEqual(text.range, newText.range)
    }

    func testParent() {
        let document = Document(Paragraph(Strong(Text("OK"))))
        XCTAssertNil(document.parent)

        let paragraph = document.child(at: 0) as! Paragraph
        XCTAssertTrue(paragraph.parent!.isIdentical(to: document))

        let strong = paragraph.child(at: 0) as! Strong
        XCTAssertTrue(strong.parent!.isIdentical(to: paragraph))

        let text = strong.child(at: 0) as! Text
        XCTAssertTrue(text.parent!.isIdentical(to: strong))
    }

    func testChildren() {
        let children = [
            Paragraph(Text("First")),
            Paragraph(Text("Second")),
            Paragraph(Text("Third")),
        ]

        let document = Document(children)
        XCTAssertEqual(3, document.childCount)
        for (child, gottenChild) in zip(children, document.children) {
            XCTAssertEqual(child.debugDescription(), gottenChild.detachedFromParent.debugDescription())
        }
    }

    func testChildrenReversed() {
        let children = [
            Paragraph(Text("First")),
            Paragraph(Text("Second")),
            Paragraph(Text("Third")),
        ]

        let document = Document(children)
        XCTAssertEqual(3, document.childCount)
        for (child, gottenChild) in zip(children.reversed(), document.children.reversed()) {
            XCTAssertEqual(child.debugDescription(), gottenChild.detachedFromParent.debugDescription())
        }
    }

    func testChildCount() {
        XCTAssertEqual(0, Document().childCount)
        XCTAssertEqual(3, Document(Paragraph(), Paragraph(), Paragraph()).childCount)
    }

    func testIndexInParent() {
        let leaf = Text("OK")
        let paragraph = Paragraph(leaf, leaf, leaf)
        let blockQuote = BlockQuote(paragraph, paragraph, paragraph)
        let document = Document(blockQuote)

        XCTAssertEqual(0, document.indexInParent)

        for (index, blockQuote) in document.children.enumerated() {
            XCTAssertEqual(index, blockQuote.indexInParent)
            for (index, paragraph) in blockQuote.children.enumerated() {
                XCTAssertEqual(index, paragraph.indexInParent)
                for (index, leaf) in paragraph.children.enumerated() {
                    XCTAssertEqual(index, leaf.indexInParent)
                }
            }
        }
    }

    func testChildThroughPath() {
        let source = "This is a [*link*](github.com)."
        let document = Document(parsing: source)

        XCTAssertTrue(document.child(at: 0)!.isIdentical(to: document.child(through: [(0, nil)])!))

        // No types specified
        let path: TypedChildIndexPath = [
            (0, nil), // Paragraph
            (1, nil), // Link
            (0, nil), // Emphasis (link text)
            (0, nil), // Text
        ]
        XCTAssertNotNil(document.child(through: path))

        // All types specified correctly
        XCTAssertNotNil(document.child(through: [
            (0, Paragraph.self),
            (1, Link.self),
            (0, Emphasis.self),
            (0, Text.self),
        ]))

        // First type unexpected
        XCTAssertNil(document.child(through: [
            (0, UnorderedList.self), // UnexpectedType
            (1, Link.self),
            (0, Emphasis.self),
            (0, Text.self),
        ]))

        // Last type unexpected
        XCTAssertNil(document.child(through: [
            (0, Paragraph.self),
            (1, Link.self),
            (0, Emphasis.self),
            (0, SoftBreak.self), // Unexpected type
        ]))
    }

    func testChild() {
        XCTAssertNil(Document().child(at: 0))
        XCTAssertNotNil(Document(Paragraph()).child(at: 0))
        XCTAssertTrue(Document(Paragraph()).child(at: 0) is Paragraph)
    }

    func testChildThroughIndices() {
        XCTAssertNil(Document().child(through: [0]))
        XCTAssertNil(Document().child(through: 0))
        XCTAssertNil(Document().child(through: [0, 0]))
        XCTAssertNil(Document().child(through: 0, 0))

        XCTAssertNotNil(Document(Paragraph()).child(through: [0]))
        XCTAssertNotNil(Document(Paragraph()).child(through: 0))
        XCTAssertNotNil(Document(Paragraph(), Paragraph()).child(through: [1]))
        XCTAssertNotNil(Document(Paragraph(), Paragraph()).child(through: 1))

        let source = "This is a [*link*](github.com)."
        let document = Document(parsing: source)
        XCTAssertNotNil(document.child(through: [
            0, // Paragraph
            1, // Link
            0, // Emphasis
            0, // Text
        ]) as? Text)
        XCTAssertNotNil(document.child(through:
            0, // Paragraph
            1, // Link
            0, // Emphasis
            0  // Text
        ) as? Text)

        XCTAssertEqual(
            document.child(through: [
                (0, Paragraph.self),
                (1, Link.self),
                (0, Emphasis.self),
                (0, Text.self),
            ])!.debugDescription(),
            document.child(through: [
                0, // Paragraph
                1, // Link
                0, // Emphasis
                0, // Text
            ])!.debugDescription()
        )
        XCTAssertEqual(
            document.child(through: [
                (0, Paragraph.self),
                (1, Link.self),
                (0, Emphasis.self),
                (0, Text.self),
            ])!.debugDescription(),
            document.child(through:
                0, // Paragraph
                1, // Link
                0, // Emphasis
                0  // Text
            )!.debugDescription()
        )
    }

    func testChildThroughIndicesWithMultipleParagraphs() {
        let source = """
This is a markup __*document*__ with *some* **more** attributes.

This is the *second* paragraph.
This is on a **new** line, but, continues on the same paragraph.

This is the *third* paragraph.
This is on a **new** line, but, continues on the same paragraph.
"""

        let document = Document(parsing: source)
        XCTAssertNotNil(document.child(through: [2, 5]) as? Strong)
    }
    
    func testChildAtPositionHasCorrectType() throws {
        let source = "This is a [*link*](github.com). And some **bold** and *italic* text."
        
        /*
         Document
         └─ Paragraph
        */
        let document = Document(parsing: source)
        let paragraph = try XCTUnwrap(document.child(at: 0))
        assertEqualType(paragraph, Paragraph.self)
        
        /*
            ├─ Text "This is a "
            ├─ Link destination: "github.com"
            │  └─ Emphasis
            │     └─ Text "link"
         
        */
        assertEqualType(paragraph.child(at: 0), Text.self)
        assertEqualType(paragraph.child(at: 1), Link.self)
        assertEqualType(paragraph.child(at: 1)?.child(at: 0), Emphasis.self)
        assertEqualType(paragraph.child(at: 1)?.child(at: 0)?.child(at: 0), Text.self)
        
        /*
            ├─ Text ". And some "
            ├─ Strong
            │  └─ Text "bold"
        */
        assertEqualType(paragraph.child(at: 2), Text.self)
        assertEqualType(paragraph.child(at: 3), Strong.self)
        assertEqualType(paragraph.child(at: 3)?.child(at: 0), Text.self)
        
        /*
            ├─ Text " and "
            ├─ Emphasis
            │  └─ Text "italic"
            └─ Text " text."
        */
        assertEqualType(paragraph.child(at: 4), Text.self)
        assertEqualType(paragraph.child(at: 5), Emphasis.self)
        assertEqualType(paragraph.child(at: 5)?.child(at: 0), Text.self)
        assertEqualType(paragraph.child(at: 6), Text.self)
        
        XCTAssertNil(paragraph.child(at: 7))
    }
    
    func testChildAtPositionHasCorrectMetadata() throws {
        let source = "This is a [*link*](github.com). And some **bold** and *italic* text."
        
        let document = Document(parsing: source)
        let paragraph = try XCTUnwrap(document.child(at: 0) as? Paragraph)
        
        for (index, sequencedChild) in paragraph.children.enumerated() {
            let indexedChild = try XCTUnwrap(paragraph.child(at: index))
            
            let indexedChildMetadata = indexedChild.raw.metadata
            let sequencedChildMetadata = sequencedChild.raw.metadata
            
            XCTAssertEqual(indexedChildMetadata.id, sequencedChildMetadata.id)
            XCTAssertEqual(indexedChildMetadata.indexInParent, sequencedChildMetadata.indexInParent)
            XCTAssertEqual(indexedChildMetadata.indexInParent, index)
        }
    }
    
    func testNestedChildAtPositionHasCorrectMetadata() throws {
        let source = "This is some **bold** and *italic* text and a [multi-formatted *link* **to** `github`](github.com)."
        
        let document = Document(parsing: source)
        let link = try XCTUnwrap(document.child(at: 0)?.child(at: 5) as? Link)
        XCTAssertEqual(link.indexInParent, 5)
        
        for (index, sequencedChild) in link.children.enumerated() {
            let indexedChild = try XCTUnwrap(link.child(at: index))
            
            let indexedChildMetadata = indexedChild.raw.metadata
            let sequencedChildMetadata = sequencedChild.raw.metadata
            
            XCTAssertEqual(indexedChildMetadata.id, sequencedChildMetadata.id)
            XCTAssertEqual(indexedChildMetadata.indexInParent, sequencedChildMetadata.indexInParent)
            XCTAssertEqual(indexedChildMetadata.indexInParent, index)
        }
    }
    
    func testChildAtPositionHasCorrectDataID() throws {
        let source = "This is a [*link*](github.com). And some **bold** and *italic* text."
        
        let document = Document(parsing: source)
        let paragraph = try XCTUnwrap(document.child(at: 0) as? Paragraph)
        
        for (index, sequencedChild) in paragraph.children.enumerated() {
            let indexedChild = try XCTUnwrap(paragraph.child(at: index))
            
            XCTAssertEqual(indexedChild._data.id, sequencedChild._data.id)
        }
    }
    
    func testNestedChildAtPositionHasCorrectDataID() throws {
        let source = "This is some **bold** and *italic* text and a [multi-formatted *link* **to** `github`](github.com)."
        
        let document = Document(parsing: source)
        let link = try XCTUnwrap(document.child(at: 0)?.child(at: 5) as? Link)
        
        for (index, sequencedChild) in link.children.enumerated() {
            let indexedChild = try XCTUnwrap(link.child(at: index))
            
            XCTAssertEqual(indexedChild._data.id, sequencedChild._data.id)
        }
    }
    
    func assertEqualType<FirstType, SecondType>(
        _ first: FirstType,
        _ second: SecondType.Type,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard first is SecondType else {
            XCTFail("'\(type(of: first))' is not expected type '\(second)'", file: file, line: line)
            return
        }
    }
}
