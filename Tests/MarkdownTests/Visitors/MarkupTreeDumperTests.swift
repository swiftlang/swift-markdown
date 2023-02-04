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
        Document @1:1-45:90 Root #\(everythingDocument.raw.metadata.id.rootId) #0
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
        ├─ UnorderedList @18:1-20:1 #48
        │  ├─ ListItem @18:1-18:37 #49 checkbox: [x]
        │  │  └─ Paragraph @18:7-18:37 #50
        │  │     └─ Text @18:7-18:37 #51 "Combine flour and baking soda."
        │  └─ ListItem @19:1-20:1 #52 checkbox: [ ]
        │     └─ Paragraph @19:7-19:30 #53
        │        └─ Text @19:7-19:30 #54 "Combine sugar and eggs."
        ├─ CodeBlock @21:1-25:4 #55 language: swift
        │  func foo() {
        │      let x = 1
        │  }
        ├─ CodeBlock @27:5-28:1 #56 language: none
        │  // Is this real code? Or just fantasy?
        ├─ Paragraph @29:1-29:31 #57
        │  ├─ Text @29:1-29:12 #58 "This is an "
        │  ├─ Link @29:12-29:30 #59 destination: "topic://autolink"
        │  │  └─ Text @29:13-29:29 #60 "topic://autolink"
        │  └─ Text @29:30-29:31 #61 "."
        ├─ ThematicBreak @31:1-32:1 #62
        ├─ HTMLBlock @33:1-35:5 #63
        │  <a href="foo.png">
        │  An HTML Block.
        │  </a>
        ├─ Paragraph @37:1-37:33 #64
        │  ├─ Text @37:1-37:14 #65 "This is some "
        │  ├─ InlineHTML @37:14-37:17 #66 <p>
        │  ├─ Text @37:17-37:28 #67 "inline html"
        │  ├─ InlineHTML @37:28-37:32 #68 </p>
        │  └─ Text @37:32-37:33 #69 "."
        ├─ Paragraph @39:1-40:6 #70
        │  ├─ Text @39:1-39:7 #71 "line"
        │  ├─ LineBreak #72
        │  └─ Text @40:1-40:6 #73 "break"
        ├─ Paragraph @42:1-43:6 #74
        │  ├─ Text @42:1-42:5 #75 "soft"
        │  ├─ SoftBreak #76
        │  └─ Text @43:1-43:6 #77 "break"
        └─ HTMLBlock @45:1-45:90 #78
           <!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
        """
        XCTAssertEqual(expectedDump, everythingDocument.debugDescription(options: [.printEverything]))
    }
}
