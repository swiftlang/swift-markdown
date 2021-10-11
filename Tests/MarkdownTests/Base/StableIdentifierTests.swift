/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

/// Test that unique identifiers aren't recreated for the same elements.
final class StableIdentifierTests: XCTestCase {
    /// Children are constructed on the fly; test that each time they are gotten, they have the same identifier.
    func testStableIdentifiers() {
        let paragraph = Paragraph(Emphasis(Text("OK.")))

        // A copy of a node should have the same identifier.
        let paragraphCopy = paragraph
        XCTAssertTrue(paragraph.isIdentical(to: paragraphCopy))

        // A child gotten twice should have the same identifier both times.
        XCTAssertTrue(paragraph.child(at: 0)!.isIdentical(to: paragraph.child(at: 0)!))

        // Similarly, for deeper nodes.
        XCTAssertTrue(paragraph.child(at: 0)!.child(at: 0)!.isIdentical(to: paragraph.child(at: 0)!.child(at: 0)!))
    }
}
