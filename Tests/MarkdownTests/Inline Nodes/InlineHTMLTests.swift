/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

class InlineHTMLTests: XCTestCase {
    func testInlineHTMLRawHTML() {
        let rawHTML = "<b>bold</b>"
        let rawHTML2 = "<p>para</p>"
        
        let inlineHTML = InlineHTML(rawHTML)
        XCTAssertEqual(rawHTML, inlineHTML.rawHTML)

        var newInlineHTML = inlineHTML
        newInlineHTML.rawHTML = rawHTML2
        XCTAssertEqual(rawHTML2, newInlineHTML.rawHTML)
        XCTAssertFalse(inlineHTML.isIdentical(to: newInlineHTML))
    }
}
