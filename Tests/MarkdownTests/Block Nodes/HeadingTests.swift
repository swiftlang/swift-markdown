/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

class HeadingTests: XCTestCase {
    func testLevel() {
        let heading = Heading(level: 1, [Text("Some text")])
        XCTAssertEqual(1, heading.level)

        var newHeading = heading
        newHeading.level = 2
        XCTAssertEqual(2, newHeading.level)
        XCTAssertFalse(heading.isIdentical(to: newHeading))

        // If you don't actually change the level, you get the same node back.
        var newHeadingUnchanged = heading
        newHeadingUnchanged.level = heading.level
        XCTAssertTrue(heading.isIdentical(to: newHeadingUnchanged))
        XCTAssertTrue(heading.isIdentical(to: newHeadingUnchanged))
    }
}
