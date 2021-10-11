/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import Markdown
import XCTest

class ParsedRangePreservedAfterEditingTests: XCTestCase {
    func testNil() {
        var document = Document()
        XCTAssertNil(document.range)

        document = document.withUncheckedChildren([Paragraph()]) as! Document
        XCTAssertNil(document.range)
    }

    func testParsed() {
        let source = """
        First element is a paragraph.

        - A
        - B

        Third element is a paragraph.
        """
        var document = Document(parsing: source)
        document.setBlockChildren(document.children.map { child -> BlockMarkup in
            guard let existingParagraph = child as? Paragraph else {
                return Paragraph(Text("Replaced paragraph."))
            }
            return existingParagraph
        })
        XCTAssertEqual(3, document.childCount)
        XCTAssertEqual(SourceLocation(line: 1, column: 1, source: nil)..<SourceLocation(line: 1, column: 30, source: nil),
                       document.child(at: 0)?.range)
        XCTAssertNil(document.child(at: 1)?.range)
        XCTAssertEqual(SourceLocation(line: 6, column: 1, source: nil)..<SourceLocation(line: 6, column: 30, source: nil),
                       document.child(at: 2)?.range)
    }

    func testComplexEdit() {
        // Replace all `Text` elements with `Emphasis(Text)`.
        // All existing `Text` elements should keep their parsed range.
        // All `Emphasis` elements should have `nil` parsed range.
        // Everything else should still have their parsed range.
        let source = """
        - 1
          - 2
            - 3
              - 4
                - 5

        ## **sdfsdf**
        """
        let document = Document(parsing: source)

        /// Verifies that all elements have a non-nil range.
        struct VerifyAllRangesInPlace: MarkupWalker {
            mutating func defaultVisit(_ markup: Markup) {
                XCTAssertNotNil(markup.range)
            }
        }

        do {
            var rangeVerifier = VerifyAllRangesInPlace()
            rangeVerifier.visit(document)
        }

        /// Wraps all ``Text`` elements in ``Emphasis``.
        struct TextReplacer: MarkupRewriter {
            mutating func visitText(_ text: Text) -> Markup? {
                return Emphasis(text)
            }
        }

        var textReplacer = TextReplacer()
        let newDocument = textReplacer.visit(document) as! Document

        /// Verifies that all ``Text`` elements have a non-nil range,
        /// all ``Emphasis`` elements do not have a nil range, and
        /// all other elements have a non-nil range.
        struct VerifyTextRangesInPlaceAndEmphasisRangesNil: MarkupWalker {
            mutating func visitText(_ text: Text) {
                XCTAssertNotNil(text.range)
            }

            mutating func visitEmphasis(_ emphasis: Emphasis) {
                XCTAssertNil(emphasis.range)
                descendInto(emphasis)
            }

            mutating func defaultVisit(_ markup: Markup) {
                XCTAssertNotNil(markup.range)
                descendInto(markup)
            }
        }

        do {
            var rangeVerifier = VerifyTextRangesInPlaceAndEmphasisRangesNil()
            rangeVerifier.visit(newDocument)
        }
    }
}
