/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

class TextTests: XCTestCase {
    func testWithText() {
        let string = "OK"
        let text = Text(string)
        XCTAssertEqual(string, text.string)
        
        let string2 = "Changed"
        var newText = text
        newText.string = string2
        XCTAssertEqual(string2, newText.string)
        XCTAssertFalse(text.isIdentical(to: newText))
    }
}
