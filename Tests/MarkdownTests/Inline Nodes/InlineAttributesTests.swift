/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

class InlineAttributesTests: XCTestCase {
    func testInlineAttributesAttributes() {
        let attributes = "rainbow: 'extreme'"
        let inlineAttributes = InlineAttributes(attributes: attributes)
        XCTAssertEqual(attributes, inlineAttributes.attributes)
        XCTAssertEqual(0, inlineAttributes.childCount)

        let newAttributes = "rainbow: 'medium'"
        var newInlineAttributes = inlineAttributes
        newInlineAttributes.attributes = newAttributes
        XCTAssertEqual(newAttributes, newInlineAttributes.attributes)
        XCTAssertFalse(inlineAttributes.isIdentical(to: newInlineAttributes))
    }
    
    func testInlineAttributesFromSequence() {
        let children = [Text("Hello, world!")]
        let inlineAttributes = InlineAttributes(attributes: "rainbow: 'extreme'", children)
        let expectedDump = """
            InlineAttributes attributes: `rainbow: 'extreme'`
            └─ Text "Hello, world!"
            """
        XCTAssertEqual(expectedDump, inlineAttributes.debugDescription())
    }
}
