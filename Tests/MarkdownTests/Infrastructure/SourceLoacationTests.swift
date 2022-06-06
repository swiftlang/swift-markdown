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
        func helper(source: String) throws {
            print("source:: \(source)")
            print("String.count: \(source.count)")
            print("NSString.length: \((source as NSString).length)")
            print("unicodeScalars.count: \(source.unicodeScalars.count)")
            print("utf8.count: \(source.utf8.count)")

            let document = Document(parsing: source)
            let range = try XCTUnwrap(document.range)
            print("range: \(range)")
            XCTAssertEqual(range.upperBound.column - 1, source.utf8.count)
        }

        // Emoji
        try helper(source: "🇺🇳")
        // CJK Character
        try helper(source: "叶")
    }
}
