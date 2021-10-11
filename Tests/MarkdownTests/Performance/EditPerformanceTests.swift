/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown

final class EditPerformanceTests: XCTestCase {
    static let maxDepth = 5000
    /// Test the performance of changing a leaf in an unrealistically deep markup tree.
    func testChangeTextInDeepTree() {
        func buildDeepListItem(depth: Int) -> ListItem {
            guard depth < EditPerformanceTests.maxDepth else {
                return ListItem(Paragraph(Text("A"), Text("B"), Text("C")))
            }
            return ListItem(buildDeepList(depth: depth + 1))
        }

        func buildDeepList(depth: Int = 0) -> UnorderedList {
            guard depth < EditPerformanceTests.maxDepth else {
                return UnorderedList(buildDeepListItem(depth: depth))
            }
            return UnorderedList(buildDeepListItem(depth: depth + 1))
        }

        let list = buildDeepList()
        var deepChild: Markup = list
        while let child = deepChild.child(at: 0) {
            deepChild = child
        }

        var deepText = (deepChild as! Text)
        measure {
            deepText.string = "Z"
        }
    }

    /// Test the performance of change an element among unrealistically many siblings.
    func testChangeTextInWideParagraph() {
        let paragraph = Paragraph((0..<10000).map { _ in Text("OK") })
        var firstText = paragraph.child(at: 0) as! Text
        measure {
            firstText.string = "OK"
        }
    }
}
