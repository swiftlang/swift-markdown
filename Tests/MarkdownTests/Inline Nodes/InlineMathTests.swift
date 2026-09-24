/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class InlineMathTests: XCTestCase {
    func testInlineMathCode() {
        let math = InlineMath("x^2 + y^2")
        XCTAssertEqual("x^2 + y^2", math.code)
        XCTAssertEqual(0, math.childCount)

        var editedMath = math
        editedMath.code = "\\frac{a}{b}"
        XCTAssertEqual("\\frac{a}{b}", editedMath.code)
        XCTAssertFalse(math.isIdentical(to: editedMath))
    }

    func testDetectionFromDelimiters() {
        let source = "The sum is $x + y$."

        do { // option on
            let document = Document(parsing: source, options: .parseMath)
            guard let paragraph = document.child(at: 0) as? Paragraph else {
                XCTFail("Expected paragraph")
                return
            }
            XCTAssertEqual(3, paragraph.childCount)
            guard let inlineMath = paragraph.child(at: 1) as? InlineMath else {
                XCTFail("Expected InlineMath")
                return
            }
            XCTAssertEqual("x + y", inlineMath.code)
        }

        do { // option off
            let document = Document(parsing: source)
            guard let paragraph = document.child(at: 0) as? Paragraph else {
                XCTFail("Expected paragraph")
                return
            }
            XCTAssertTrue(paragraph.children.allSatisfy { !($0 is InlineMath) })
        }
    }

    func testNoDetectionForCurrencyStyleDollars() {
        let source = "It costs $5 and $10."
        let document = Document(parsing: source, options: .parseMath)
        guard let paragraph = document.child(at: 0) as? Paragraph else {
            XCTFail("Expected paragraph")
            return
        }
        XCTAssertTrue(paragraph.children.allSatisfy { !($0 is InlineMath) })
    }

    func testEscapedDelimitersAreNotParsed() {
        let source = #"Escaped \\$x$ and $y\\$ stay text."#
        let document = Document(parsing: source, options: .parseMath)
        guard let paragraph = document.child(at: 0) as? Paragraph else {
            XCTFail("Expected paragraph")
            return
        }
        XCTAssertTrue(paragraph.children.allSatisfy { !($0 is InlineMath) })
    }

    func testMultipleInlineMathSegments() {
        let source = "A $x$ and $y$."
        let document = Document(parsing: source, options: .parseMath)
        guard let paragraph = document.child(at: 0) as? Paragraph else {
            XCTFail("Expected paragraph")
            return
        }
        XCTAssertEqual(5, paragraph.childCount)
        XCTAssertEqual("x", (paragraph.child(at: 1) as? InlineMath)?.code)
        XCTAssertEqual("y", (paragraph.child(at: 3) as? InlineMath)?.code)
    }

    func testNoDetectionWhenWhitespaceTouchesDelimiters() {
        let source = "$ x$ and $y $"
        let document = Document(parsing: source, options: .parseMath)
        guard let paragraph = document.child(at: 0) as? Paragraph else {
            XCTFail("Expected paragraph")
            return
        }
        XCTAssertTrue(paragraph.children.allSatisfy { !($0 is InlineMath) })
    }

    func testNoDetectionAcrossSoftBreaks() {
        let source = """
        A $x
        + y$
        """
        let document = Document(parsing: source, options: .parseMath)
        guard let paragraph = document.child(at: 0) as? Paragraph else {
            XCTFail("Expected paragraph")
            return
        }
        XCTAssertTrue(paragraph.children.allSatisfy { !($0 is InlineMath) })
    }

    func testNoDetectionForUnmatchedOpeningDelimiter() {
        let source = "A $x + y."
        let document = Document(parsing: source, options: .parseMath)
        guard let paragraph = document.child(at: 0) as? Paragraph else {
            XCTFail("Expected paragraph")
            return
        }
        XCTAssertTrue(paragraph.children.allSatisfy { !($0 is InlineMath) })
    }

    func testNoDetectionForUnmatchedClosingDelimiter() {
        let source = "A x + y$."
        let document = Document(parsing: source, options: .parseMath)
        guard let paragraph = document.child(at: 0) as? Paragraph else {
            XCTFail("Expected paragraph")
            return
        }
        XCTAssertTrue(paragraph.children.allSatisfy { !($0 is InlineMath) })
    }

    func testAdjacentDelimitersFormSingleInlineMathSpan() {
        let source = "$x$$y$"
        let document = Document(parsing: source, options: .parseMath)
        guard let paragraph = document.child(at: 0) as? Paragraph else {
            XCTFail("Expected paragraph")
            return
        }

        XCTAssertEqual(1, paragraph.childCount)
        XCTAssertEqual("x$$y", (paragraph.child(at: 0) as? InlineMath)?.code)
    }

    func testDetectionInsideEmphasisButNotInsideInlineCode() {
        let source = "*a $x$* and `$y$`"
        let document = Document(parsing: source, options: .parseMath)
        guard let paragraph = document.child(at: 0) as? Paragraph else {
            XCTFail("Expected paragraph")
            return
        }

        guard let emphasis = paragraph.child(at: 0) as? Emphasis else {
            XCTFail("Expected Emphasis")
            return
        }
        XCTAssertTrue(emphasis.children.contains(where: { $0 is InlineMath }))

        guard let inlineCode = paragraph.children.first(where: { $0 is InlineCode }) as? InlineCode else {
            XCTFail("Expected InlineCode")
            return
        }
        XCTAssertEqual("$y$", inlineCode.code)
    }

    func testFormatAndHTML() {
        let document = Document([Paragraph(Text("A "), InlineMath("x + y"), Text(" B"))])
        XCTAssertEqual("A $x + y$ B", document.format())
        XCTAssertEqual(
            "<p>A <code class=\"language-math\">x + y</code> B</p>\n",
            HTMLFormatter.format(document)
        )
    }

    func testRangePreservedAfterParsing() {
        let source = URL(string: "https://swift.org/math.md")
        let document = Document(
            parsing: "$x$",
            source: source,
            options: .parseMath
        )
        guard let paragraph = document.child(at: 0) as? Paragraph,
              let inlineMath = paragraph.child(at: 0) as? InlineMath else {
            XCTFail("Expected InlineMath")
            return
        }

        XCTAssertEqual(1, inlineMath.range?.lowerBound.line)
        XCTAssertEqual(1, inlineMath.range?.lowerBound.column)
        XCTAssertEqual(1, inlineMath.range?.upperBound.line)
        XCTAssertEqual(4, inlineMath.range?.upperBound.column)
        XCTAssertEqual(source, inlineMath.range?.lowerBound.source)
        XCTAssertEqual(source, inlineMath.range?.upperBound.source)
    }

    func testRangePreservedWithinLargerText() {
        let source = URL(string: "https://swift.org/math.md")
        let document = Document(
            parsing: "A $xy$ B",
            source: source,
            options: .parseMath
        )
        guard let paragraph = document.child(at: 0) as? Paragraph,
              let inlineMath = paragraph.child(at: 1) as? InlineMath else {
            XCTFail("Expected InlineMath")
            return
        }

        XCTAssertEqual(1, inlineMath.range?.lowerBound.line)
        XCTAssertEqual(3, inlineMath.range?.lowerBound.column)
        XCTAssertEqual(1, inlineMath.range?.upperBound.line)
        XCTAssertEqual(7, inlineMath.range?.upperBound.column)
    }
}
