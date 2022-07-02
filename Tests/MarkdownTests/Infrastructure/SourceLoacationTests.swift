/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import Markdown
import XCTest

class SourceLoacationTests: XCTestCase {
    func testNonAsciiCharacterColumn() throws {
        func assertColumnNumberAssumesUTF8Encoding(text: String) throws {
            let document = Document(parsing: text)
            let range = try XCTUnwrap(document.range)
            XCTAssertEqual(range.upperBound.column - 1, text.utf8.count)
        }

        // Emoji
        try assertColumnNumberAssumesUTF8Encoding(text: "🇺🇳")
        // CJK Character
        try assertColumnNumberAssumesUTF8Encoding(text: "叶")
    }
}
