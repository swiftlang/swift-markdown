/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class PlainTextConvertibleMarkupTests: XCTestCase {
    func testParagraph() {
        let paragraph = Paragraph(
            Text("This is a "),
            Emphasis(Text("paragraph")),
            Text("."))

        XCTAssertEqual("This is a paragraph.", paragraph.plainText)
    }

    func testEmphasis() {
        let emphasis = Emphasis(Text("Emphasis"))
        XCTAssertEqual("Emphasis", emphasis.plainText)
    }

    func testImage() {
        let image = Image(source: "test.png", title: "", Text("This "), Text("is "), Text("an "), Text("image."))
        XCTAssertEqual("This is an image.", image.plainText)
    }

    func testLink() {
        let link = Link(destination: "test.png",
                        Text("This "),
                        Text("is "),
                        Text("a "),
                        Text("link."))
        XCTAssertEqual("This is a link.", link.plainText)
    }

    func testStrong() {
        let strong = Strong(Text("Strong"))
        XCTAssertEqual("Strong", strong.plainText)
    }

    func testCustomInline() {
        let customInline = CustomInline("Custom inline")
        XCTAssertEqual("Custom inline", customInline.plainText)
    }

    func testInlineCode() {
        let inlineCode = InlineCode("foo")
        XCTAssertEqual("`foo`", inlineCode.plainText)
    }

    func testInlineHTML() {
        let inlineHTML = InlineHTML("<br />")
        XCTAssertEqual("<br />", inlineHTML.plainText)
    }

    func testLineBreak() {
        XCTAssertEqual("\n", LineBreak().plainText)
    }

    func testSoftBreak() {
        XCTAssertEqual(" ", SoftBreak().plainText)
    }

    func testText() {
        let text = Text("OK")
        XCTAssertEqual("OK", text.plainText)
    }
}
