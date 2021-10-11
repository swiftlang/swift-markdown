/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown

final class MarkupChildrenPerformanceTests: XCTestCase {
    /// Iteration over the children should be fast: no heap allocation should be necessary.
    let paragraph = Paragraph((0..<10000).map { _ in Text("OK") })
    func testIterateChildrenForward() {
        measure {
            for child in paragraph.children {
                _ = child
            }
        }
    }

    /// Iteration over the children in reverse should be fast: no heap allocation should be necessary.
    func testIterateChildrenReversed() {
        let paragraph = Paragraph((0..<10000).map { _ in Text("OK") })
        measure {
            for child in paragraph.children.reversed() {
                _ = child
            }
        }
    }

    func testDropFirst() {
        let paragraph = Paragraph((0..<10000).map { _ in Text("OK") })
        measure {
            for child in paragraph.children.dropFirst(5000) {
                _ = child
            }
        }
    }

    func testSuffix() {
        let paragraph = Paragraph((0..<10000).map { _ in Text("OK") })
        measure {
            for child in paragraph.children.suffix(5000) {
                _ = child
            }
        }
    }
}
