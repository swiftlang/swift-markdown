/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class LineBreakTests: XCTestCase {
    /// Tests that creation doesn't crash.
    func testLineBreak() {
        _ = LineBreak()
    }
    
    /// Test that line breaks are parsed correctly.
    /// (Lots of folks have trailing whitespace trimming on).
    func testParseLineBreak() {
        let source = "Paragraph.  \nStill the same paragraph."
        let document = Document(parsing: source)
        let paragraph = document.child(at: 0) as! Paragraph
        XCTAssertTrue(Array(paragraph.children)[1] is LineBreak)
    }
}
