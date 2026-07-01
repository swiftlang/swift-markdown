/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class BlockMathTests: XCTestCase {
    func testBlockMathCode() {
        let math = BlockMath("x^2 + y^2")
        XCTAssertEqual("x^2 + y^2", math.code)
        XCTAssertEqual(0, math.childCount)

        var editedMath = math
        editedMath.code = "\\frac{a}{b}"
        XCTAssertEqual("\\frac{a}{b}", editedMath.code)
        XCTAssertFalse(math.isIdentical(to: editedMath))
    }

    func testDetectionFromDelimiters() {
        let source = """
        $$
        x + y
        $$
        """

        do { // option on
            let document = Document(parsing: source, options: .parseMath)
            XCTAssertEqual(1, document.childCount)
            guard let blockMath = document.child(at: 0) as? BlockMath else {
                XCTFail("Expected BlockMath")
                return
            }
            XCTAssertEqual("x + y", blockMath.code)
        }

        do { // option off
            let document = Document(parsing: source)
            XCTAssertTrue(document.child(at: 0) is Paragraph)
        }
    }

    func testSingleLineDetectionFromDelimiters() {
        let source = "$$x + y$$"
        let document = Document(parsing: source, options: .parseMath)
        guard let blockMath = document.child(at: 0) as? BlockMath else {
            XCTFail("Expected BlockMath")
            return
        }
        XCTAssertEqual("x + y", blockMath.code)
    }

    func testDetectionInsideBlockQuote() {
        let source = """
        > $$
        > x + y
        > $$
        """
        let document = Document(parsing: source, options: .parseMath)
        guard let quote = document.child(at: 0) as? BlockQuote else {
            XCTFail("Expected BlockQuote")
            return
        }
        XCTAssertTrue(quote.child(at: 0) is BlockMath)
    }

    func testNoDetectionForInlineDoubleDollars() {
        let source = "before $$x + y$$ after"
        let document = Document(parsing: source, options: .parseMath)
        guard let paragraph = document.child(at: 0) as? Paragraph else {
            XCTFail("Expected paragraph")
            return
        }
        XCTAssertFalse(paragraph.children.contains(where: { $0 is InlineMath }))
        XCTAssertFalse(paragraph.children.contains(where: { $0 is BlockMath }))
    }

    func testNoDetectionWhenClosingDelimiterHasTrailingText() {
        let source = """
        $$
        x + y
        $$ trailing
        """
        let document = Document(parsing: source, options: .parseMath)
        XCTAssertTrue(document.child(at: 0) is Paragraph)
    }

    func testNoDetectionForMixedInlineChildren() {
        let source = "$$ *x + y* $$"
        let document = Document(parsing: source, options: .parseMath)
        XCTAssertTrue(document.child(at: 0) is Paragraph)
    }

    func testNoDetectionWithBlankLinesInsideBlock() {
        let source = """
        $$
        x

        y
        $$
        """
        let document = Document(parsing: source, options: .parseMath)
        XCTAssertTrue(document.child(at: 0) is Paragraph)
    }

    func testNoDetectionForUnmatchedOpeningDelimiter() {
        let source = """
        $$
        x + y
        """
        let document = Document(parsing: source, options: .parseMath)
        XCTAssertTrue(document.child(at: 0) is Paragraph)
    }

    func testNoDetectionForUnmatchedClosingDelimiter() {
        let source = """
        x + y
        $$
        """
        let document = Document(parsing: source, options: .parseMath)
        XCTAssertTrue(document.child(at: 0) is Paragraph)
    }

    func testNoDetectionForTripleDollarDelimiters() {
        let source = """
        $$$
        x + y
        $$$
        """
        let document = Document(parsing: source, options: .parseMath)
        XCTAssertTrue(document.child(at: 0) is Paragraph)
    }

    func testDetectionWithWhitespaceAroundDelimiterLines() {
        let source = """
          $$  
        x + y
         $$
        """
        let document = Document(parsing: source, options: .parseMath)
        guard let blockMath = document.child(at: 0) as? BlockMath else {
            XCTFail("Expected BlockMath")
            return
        }
        XCTAssertEqual("x + y", blockMath.code)
    }

    func testFormatAndHTML() {
        let document = Document([BlockMath("x + y")])
        XCTAssertEqual(
            """
            $$
            x + y
            $$
            """,
            document.format()
        )
        XCTAssertEqual(
            "<pre><code class=\"language-math\">x + y</code></pre>\n",
            HTMLFormatter.format(document)
        )
    }

    func testRangePreservedAfterParsing() {
        let source = URL(string: "https://swift.org/math.md")
        let document = Document(
            parsing: """
            $$
            x + y
            $$
            """,
            source: source,
            options: .parseMath
        )
        guard let blockMath = document.child(at: 0) as? BlockMath else {
            XCTFail("Expected BlockMath")
            return
        }

        XCTAssertEqual(1, blockMath.range?.lowerBound.line)
        XCTAssertEqual(1, blockMath.range?.lowerBound.column)
        XCTAssertEqual(3, blockMath.range?.upperBound.line)
        XCTAssertEqual(3, blockMath.range?.upperBound.column)
        XCTAssertEqual(source, blockMath.range?.lowerBound.source)
        XCTAssertEqual(source, blockMath.range?.upperBound.source)
    }
}
