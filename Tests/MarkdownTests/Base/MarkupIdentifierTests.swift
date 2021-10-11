/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class MarkupIdentifierTests: XCTestCase {
    func totalElementsInTree(height h: Int, width N: Int) -> Int {
        let total =
            (pow(Double(N), Double(h + 1)) - 1)
                /
            Double(N - 1)
        return Int(total)
    }

    func buildCustomBlock(height: Int, width: Int) -> CustomBlock {
        guard height > 0 else {
            return CustomBlock()
        }
        return CustomBlock(Array(repeating: buildCustomBlock(height: height - 1, width: width), count: width))
    }

    /// No two children should have the same child identifier.
    func testChildIDsAreUnique() {
        let height = 5
        let width = 5

        let customBlock = buildCustomBlock(height: height, width: width)

        print(customBlock.debugDescription(options: .printEverything))

        struct IDCounter: MarkupWalker {
            var id = 0

            mutating func defaultVisit(_ markup: Markup) {
                XCTAssertEqual(id, markup._data.id.childId)
                id += 1
                descendInto(markup)
            }
        }

        var counter = IDCounter()
        counter.visit(customBlock)
        XCTAssertEqual(totalElementsInTree(height: height, width: width), counter.id)
    }

    /// The very first child id shall be 1 greater than that of its parent.
    func testFirstChildIdentifier() {
        func checkFirstChildOf(_ markup: Markup, expectedId: Int) {
            guard let firstChild = markup.child(at: 0) else {
                return
            }
            XCTAssertEqual(expectedId, firstChild.raw.metadata.id.childId)
            // As we descend depth-first, each first child identifier shall be one more than the last.
            checkFirstChildOf(firstChild, expectedId: expectedId + 1)
        }

        checkFirstChildOf(buildCustomBlock(height: 100, width: 1), expectedId: 1)
    }

    func testNextSiblingIdentifier() {
        let height = 2
        let width = 100
        let customBlock = buildCustomBlock(height: height, width: width)

        var id = 1
        for child in customBlock.children {
            // Every branch in the tree should use 1 + 100 identifiers.
            XCTAssertEqual(id, child.raw.metadata.id.childId)
            id += width + 1
        }
    }

    func testPreviousSiblingIdentifier() {
        let height = 2
        let width = 100
        let customBlock = buildCustomBlock(height: height, width: width)

        var id = totalElementsInTree(height: height, width: width)
        for child in customBlock.children.reversed() {
            // Every branch in the tree should use 1 + 100 identifiers.
            XCTAssertEqual(id, child.raw.metadata.id.childId)
            id -= width + 1
        }
    }
}
