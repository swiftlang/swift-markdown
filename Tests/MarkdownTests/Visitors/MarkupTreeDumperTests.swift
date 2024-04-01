/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class MarkupTreeDumperTests: XCTestCase {
    func testDumpEverything() {
        let expectedDump = """
        Document @1:1-42:90 Root #\(everythingDocument.raw.metadata.id.rootId) #0
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
        │  ├─ Image @3:51-3:64 #15 source: "foo"
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
        ├─ OrderedList @15:1-17:1 #41 startIndex: 2
        │  ├─ ListItem @15:1-15:9 #42
        │  │  └─ Paragraph @15:4-15:9 #43
        │  │     └─ Text @15:4-15:9 #44 "flour"
        │  └─ ListItem @16:1-17:1 #45
        │     └─ Paragraph @16:4-16:9 #46
        │        └─ Text @16:4-16:9 #47 "sugar"
        ├─ CodeBlock @18:1-22:4 #48 language: swift
        │  func foo() {
        │      let x = 1
        │  }
        ├─ CodeBlock @24:5-25:1 #49 language: none
        │  // Is this real code? Or just fantasy?
        ├─ Paragraph @26:1-26:31 #50
        │  ├─ Text @26:1-26:12 #51 "This is an "
        │  ├─ Link @26:12-26:30 #52 destination: "topic://autolink"
        │  │  └─ Text @26:13-26:29 #53 "topic://autolink"
        │  └─ Text @26:30-26:31 #54 "."
        ├─ ThematicBreak @28:1-29:1 #55
        ├─ HTMLBlock @30:1-32:5 #56
        │  <a href="foo.png">
        │  An HTML Block.
        │  </a>
        ├─ Paragraph @34:1-34:33 #57
        │  ├─ Text @34:1-34:14 #58 "This is some "
        │  ├─ InlineHTML @34:14-34:17 #59 <p>
        │  ├─ Text @34:17-34:28 #60 "inline html"
        │  ├─ InlineHTML @34:28-34:32 #61 </p>
        │  └─ Text @34:32-34:33 #62 "."
        ├─ Paragraph @36:1-37:6 #63
        │  ├─ Text @36:1-36:7 #64 "line"
        │  ├─ LineBreak #65
        │  └─ Text @37:1-37:6 #66 "break"
        ├─ Paragraph @39:1-40:6 #67
        │  ├─ Text @39:1-39:5 #68 "soft"
        │  ├─ SoftBreak #69
        │  └─ Text @40:1-40:6 #70 "break"
        └─ HTMLBlock @42:1-42:90 #71
           <!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
        """
        print(everythingDocument.debugDescription(options: [.printEverything]))
        XCTAssertEqual(expectedDump, everythingDocument.debugDescription(options: [.printEverything]))
    }
}
