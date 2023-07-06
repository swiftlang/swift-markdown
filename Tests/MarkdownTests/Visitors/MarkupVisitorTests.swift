/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown

class MarkupVisitorTests: XCTestCase {
    struct EmptyWalker: MarkupWalker {
        mutating func defaultVisit(_ markup: Markdown.Markup) -> Void {
            return
        }
    }
    
    // A compile time check for PAT support
    func testMarkupVisitorPrimaryAssociatedType() {
        var vistor: some MarkupVisitor<Void> = EmptyWalker()
        vistor.visit(Text(""))
    }
}
