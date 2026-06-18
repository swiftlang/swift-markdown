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

    func testOpenBackticks() {
        let double = "``"
        let document = Document(parsing: double)
        let expectedDump = """
        Document @1:1-1:3
        └─ Paragraph @1:1-1:3
           └─ Text @1:1-1:3 "``"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    // MARK: - Backtick in code voice (rdar://116587933, https://github.com/swiftlang/swift-markdown/issues/93)

    func testBacktickInCodeVoiceWithDoubleBacktickDelimiters() {
        // CommonMark: `` ` `` produces a code span containing a single backtick.
        // With parseSymbolLinks enabled, this should remain InlineCode, not become a SymbolLink.
        let source = "Use `` ` `` to delimit"
        let document = Document(parsing: source, options: .parseSymbolLinks)
        let expectedDump = """
        Document @1:1-1:23
        └─ Paragraph @1:1-1:23
           ├─ Text @1:1-1:5 "Use "
           ├─ InlineCode @1:5-1:12 ```
           └─ Text @1:12-1:23 " to delimit"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    func testBacktickInCodeVoiceWithTripleBacktickDelimiters() {
        // CommonMark: ``` ` ``` produces a code span containing a single backtick.
        // With parseSymbolLinks enabled, this should remain InlineCode, not become a SymbolLink.
        let source = "Use ``` ` ``` to delimit"
        let document = Document(parsing: source, options: .parseSymbolLinks)
        let expectedDump = """
        Document @1:1-1:25
        └─ Paragraph @1:1-1:25
           ├─ Text @1:1-1:5 "Use "
           ├─ InlineCode @1:5-1:14 ```
           └─ Text @1:14-1:25 " to delimit"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    func testDoubleBacktickSymbolLinkStillWorks() {
        // Regression guard: ``symbol`` with parseSymbolLinks should still be a SymbolLink.
        let source = "See ``foo()`` for details"
        let document = Document(parsing: source, options: .parseSymbolLinks)
        let expectedDump = """
        Document @1:1-1:26
        └─ Paragraph @1:1-1:26
           ├─ Text @1:1-1:5 "See "
           ├─ SymbolLink @1:5-1:14 destination: foo()
           └─ Text @1:14-1:26 " for details"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    func testMultipleBackticksInCodeVoice() {
        // CommonMark: ``` `` ``` produces a code span containing two backticks.
        // With parseSymbolLinks enabled, this should remain InlineCode, not become a SymbolLink.
        let source = "Use ``` `` ``` in code"
        let document = Document(parsing: source, options: .parseSymbolLinks)
        let expectedDump = """
        Document @1:1-1:23
        └─ Paragraph @1:1-1:23
           ├─ Text @1:1-1:5 "Use "
           ├─ InlineCode @1:5-1:15 ````
           └─ Text @1:15-1:23 " in code"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }
}
