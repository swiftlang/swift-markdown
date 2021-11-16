/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import Markdown
import XCTest

class BacktickTests: XCTestCase {
    func testNormalBackticks() {
        let string = "Hello `test` String"
        let document = Document(parsing: string)
        let expectedDump = """
        Document @1:1-1:20
        └─ Paragraph @1:1-1:20
           ├─ Text @1:1-1:7 "Hello "
           ├─ InlineCode @1:7-1:13 `test`
           └─ Text @1:13-1:20 " String"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    func testOpenBacktick() {
        let single = "`"
        let document = Document(parsing: single)
        let expectedDump = """
        Document @1:1-1:2
        └─ Paragraph @1:1-1:2
           └─ Text @1:1-1:2 "`"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    func testOpenBackticks(){
        let double = "``"
        let document = Document(parsing: double)
        let expectedDump = """
        Document @1:1-1:3
        └─ Paragraph @1:1-1:3
           └─ Text @1:1-1:3 "``"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }
}
