/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import Markdown
import XCTest

func assertElementDidntChange(_ element: Markup, assertedStructure expected: Markup, expectedId: MarkupIdentifier) {
    XCTAssertTrue(element.hasSameStructure(as: expected))
    XCTAssertEqual(element._data.id, expectedId)
}
