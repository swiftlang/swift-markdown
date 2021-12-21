/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class RawMarkupToMarkupTests: XCTestCase {
    func testParagraph() {
        XCTAssertNoThrow(try Paragraph(.paragraph(parsedRange: nil, [])))
        XCTAssertThrowsError(try Paragraph(.softBreak(parsedRange: nil)))
    }

    func testCodeBlock() {
        XCTAssertNoThrow(try CodeBlock(.codeBlock(parsedRange: nil, code: "", language: nil)))
        XCTAssertThrowsError(try CodeBlock(.softBreak(parsedRange: nil)))
    }

    func testHTMLBlock() {
        XCTAssertNoThrow(try HTMLBlock(.htmlBlock(parsedRange: nil, html: "")))
        XCTAssertThrowsError(try HTMLBlock(.softBreak(parsedRange: nil)))
    }

    func testHeading() {
        XCTAssertNoThrow(try Heading(.heading(level: 1, parsedRange: nil, [])))
        XCTAssertThrowsError(try Heading(.softBreak(parsedRange: nil)))
    }

    func testThematicBreak() {
        XCTAssertNoThrow(try ThematicBreak(.thematicBreak(parsedRange: nil)))
        XCTAssertThrowsError(try ThematicBreak(.softBreak(parsedRange: nil)))
    }

    func testBlockQuote() {
        XCTAssertNoThrow(try BlockQuote(.blockQuote(parsedRange: nil, [])))
        XCTAssertThrowsError(try BlockQuote(.softBreak(parsedRange: nil)))
    }

    func testListItem() {
        XCTAssertNoThrow(try ListItem(.listItem(checkbox: .none, parsedRange: nil, [])))
        XCTAssertThrowsError(try ListItem(.softBreak(parsedRange: nil)))
    }

    func testOrderedList() {
        XCTAssertNoThrow(try OrderedList(.orderedList(parsedRange: nil, [])))
        XCTAssertThrowsError(try OrderedList(.softBreak(parsedRange: nil)))
    }

    func testUnorderedList() {
        XCTAssertNoThrow(try UnorderedList(.unorderedList(parsedRange: nil, [])))
        XCTAssertThrowsError(try UnorderedList(.softBreak(parsedRange: nil)))
    }

    func testCustomBlock() {
        XCTAssertNoThrow(try CustomBlock(.customBlock(parsedRange: nil, [])))
        XCTAssertThrowsError(try CustomBlock(.softBreak(parsedRange: nil)))
    }

    func testCustomInline() {
        XCTAssertNoThrow(try CustomInline(.customInline(parsedRange: nil, text: "")))
        XCTAssertThrowsError(try CustomInline(.softBreak(parsedRange: nil)))
    }

    func testInlineCode() {
        XCTAssertNoThrow(try InlineCode(.inlineCode(parsedRange: nil, code: "")))
        XCTAssertThrowsError(try InlineCode(.softBreak(parsedRange: nil)))
    }
    
    func testInlineHTML() {
        XCTAssertNoThrow(try InlineHTML(.inlineHTML(parsedRange: nil, html: "")))
        XCTAssertThrowsError(try InlineHTML(.softBreak(parsedRange: nil)))
    }

    func testLineBreak() {
        XCTAssertNoThrow(try LineBreak(.lineBreak(parsedRange: nil)))
        XCTAssertThrowsError(try LineBreak(.softBreak(parsedRange: nil)))
    }

    func testSoftBreak() {
        XCTAssertNoThrow(try SoftBreak(.softBreak(parsedRange: nil)))
        XCTAssertThrowsError(try SoftBreak(.lineBreak(parsedRange: nil)))
    }

    func testText() {
        XCTAssertNoThrow(try Text(.text(parsedRange: nil, string: "")))
        XCTAssertThrowsError(try Text(.softBreak(parsedRange: nil)))
    }

    func testEmphasis() {
        XCTAssertNoThrow(try Emphasis(.emphasis(parsedRange: nil, [])))
        XCTAssertThrowsError(try Emphasis(.softBreak(parsedRange: nil)))
    }

    func testStrong() {
        XCTAssertNoThrow(try Strong(.strong(parsedRange: nil, [])))
        XCTAssertThrowsError(try Strong(.softBreak(parsedRange: nil)))
    }

    func testImage() {
        XCTAssertNoThrow(try Image(.image(source: "", title: "", parsedRange: nil, [])))
        XCTAssertThrowsError(try Image(.softBreak(parsedRange: nil)))
    }

    func testLink() {
        XCTAssertNoThrow(try Link(.link(destination: "", parsedRange: nil, [])))
        XCTAssertThrowsError(try Link(.softBreak(parsedRange: nil)))
    }
}
