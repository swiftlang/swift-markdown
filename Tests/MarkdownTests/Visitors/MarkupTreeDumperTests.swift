/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class MarkupTreeDumperTests: XCTestCase {
    func testDumpEverything() {
        let expectedDump = """
        Document @1:1-39:90 Root #\(everythingDocument.raw.metadata.id.rootId) #0
        ├─ Heading @1:1-1:9 #1 level: 1
        │  └─ Text @1:3-1:9 #2 "Header"
        ├─ Paragraph @3:1-3:65 #3
        │  ├─ Emphasis @3:1-3:13 #4
        │  │  └─ Text @3:2-3:12 #5 "Emphasized"
        │  ├─ Text @3:13-3:14 #6 " "
        │  ├─ Strong @3:14-3:24 #7
        │  │  └─ Text @3:16-3:22 #8 "strong"
        │  ├─ Text @3:24-3:25 #9 " "
        │  ├─ InlineCode @3:25-3:38 #10 `inline code`
        │  ├─ Text @3:38-3:39 #11 " "
        │  ├─ Link @3:39-3:50 #12 destination: "foo"
        │  │  └─ Text @3:40-3:44 #13 "link"
        │  ├─ Text @3:50-3:51 #14 " "
        │  ├─ Image @3:51-3:64 #15 source: "foo" title: ""
        │  │  └─ Text @3:53-3:58 #16 "image"
        │  └─ Text @3:64-3:65 #17 "."
        ├─ UnorderedList @5:1-9:1 #18
        │  ├─ ListItem @5:1-5:7 #19
        │  │  └─ Paragraph @5:3-5:7 #20
        │  │     └─ Text @5:3-5:7 #21 "this"
        │  ├─ ListItem @6:1-6:5 #22
        │  │  └─ Paragraph @6:3-6:5 #23
        │  │     └─ Text @6:3-6:5 #24 "is"
        │  ├─ ListItem @7:1-7:4 #25
        │  │  └─ Paragraph @7:3-7:4 #26
        │  │     └─ Text @7:3-7:4 #27 "a"
        │  └─ ListItem @8:1-9:1 #28
        │     └─ Paragraph @8:3-8:7 #29
        │        └─ Text @8:3-8:7 #30 "list"
        ├─ OrderedList @10:1-12:1 #31
        │  ├─ ListItem @10:1-10:8 #32
        │  │  └─ Paragraph @10:4-10:8 #33
        │  │     └─ Text @10:4-10:8 #34 "eggs"
        │  └─ ListItem @11:1-12:1 #35
        │     └─ Paragraph @11:4-11:8 #36
        │        └─ Text @11:4-11:8 #37 "milk"
        ├─ BlockQuote @13:1-13:13 #38
        │  └─ Paragraph @13:3-13:13 #39
        │     └─ Text @13:3-13:13 #40 "BlockQuote"
        ├─ CodeBlock @15:1-19:4 #41 language: swift
        │  func foo() {
        │      let x = 1
        │  }
        ├─ CodeBlock @21:5-22:1 #42 language: none
        │  // Is this real code? Or just fantasy?
        ├─ Paragraph @23:1-23:31 #43
        │  ├─ Text @23:1-23:12 #44 "This is an "
        │  ├─ Link @23:12-23:30 #45 destination: "topic://autolink"
        │  │  └─ Text @23:13-23:29 #46 "topic://autolink"
        │  └─ Text @23:30-23:31 #47 "."
        ├─ ThematicBreak @25:1-26:1 #48
        ├─ HTMLBlock @27:1-29:5 #49
        │  <a href="foo.png">
        │  An HTML Block.
        │  </a>
        ├─ Paragraph @31:1-31:33 #50
        │  ├─ Text @31:1-31:14 #51 "This is some "
        │  ├─ InlineHTML @31:14-31:17 #52 <p>
        │  ├─ Text @31:17-31:28 #53 "inline html"
        │  ├─ InlineHTML @31:28-31:32 #54 </p>
        │  └─ Text @31:32-31:33 #55 "."
        ├─ Paragraph @33:1-34:6 #56
        │  ├─ Text @33:1-33:7 #57 "line"
        │  ├─ LineBreak #58
        │  └─ Text @34:1-34:6 #59 "break"
        ├─ Paragraph @36:1-37:6 #60
        │  ├─ Text @36:1-36:5 #61 "soft"
        │  ├─ SoftBreak #62
        │  └─ Text @37:1-37:6 #63 "break"
        └─ HTMLBlock @39:1-39:90 #64
           <!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
        """
        print(everythingDocument.debugDescription(options: [.printEverything]))
        XCTAssertEqual(expectedDump, everythingDocument.debugDescription(options: [.printEverything]))
    }
}
