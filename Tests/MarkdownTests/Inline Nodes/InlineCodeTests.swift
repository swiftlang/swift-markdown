/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

class InlineCodeTests: XCTestCase {
    func testInlineCodeString() {
        let text = "foo()"
        let text2 = "bar()"
        let inlineCode = InlineCode(text)

        XCTAssertEqual(text, inlineCode.code)

        var inlineCodeWithText2 = inlineCode
        inlineCodeWithText2.code = text2

        XCTAssertEqual(text2, inlineCodeWithText2.code)
        XCTAssertFalse(inlineCode.isIdentical(to: inlineCodeWithText2))
    }
}
