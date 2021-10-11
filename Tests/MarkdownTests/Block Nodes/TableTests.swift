/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

class TableTests: XCTestCase {
    func testGetHeader() {
        do { // none
            let table = Table()
            XCTAssertTrue(table.columnAlignments.isEmpty)
            XCTAssertTrue(table.isEmpty)
        }

        do { // some
            let table = Table(header: Table.Head(Table.Cell(Text("OK"))))
            XCTAssertNotNil(table.head)
            let expectedDump = """
            Table alignments: |-|
            ├─ Head
            │  └─ Cell
            │     └─ Text "OK"
            └─ Body
            """
            XCTAssertEqual(expectedDump, table.debugDescription())
            XCTAssertTrue(table.body.isEmpty)
        }
    }

    func testSetHeader() {
        do { // non-empty -> empty
            let source = """
            |x|y|z|
            |-|-|-|
            |1|2|3|
            """
            let document = Document(parsing: source)
            var table = document.child(at: 0) as! Table
            XCTAssertFalse(table.head.isEmpty)
            table.head = []
            XCTAssertTrue(table.head.isEmpty)

            let expectedDump = """
            Document
            └─ Table alignments: |-|-|-|
               ├─ Head
               └─ Body
                  └─ Row
                     ├─ Cell
                     │  └─ Text "1"
                     ├─ Cell
                     │  └─ Text "2"
                     └─ Cell
                        └─ Text "3"
            """
            XCTAssertEqual(expectedDump, table.root.debugDescription())
        }

        do { // empty -> non-empty
            var table = Table()
            XCTAssertTrue(table.head.isEmpty)
            table.head = Table.Head(
                Table.Cell(Text("x")), Table.Cell(Text("y")), Table.Cell(Text("z"))
            )
            XCTAssertFalse(table.head.isEmpty)
            let expectedDump = """
            Table alignments: |-|-|-|
            ├─ Head
            │  ├─ Cell
            │  │  └─ Text "x"
            │  ├─ Cell
            │  │  └─ Text "y"
            │  └─ Cell
            │     └─ Text "z"
            └─ Body
            """
            XCTAssertEqual(expectedDump, table.root.debugDescription())
        }
    }

    func testGetBody() {
        do { // none
            let table = Table()
            XCTAssertEqual(0, table.body.childCount)
        }

        do { // some
            let table = Table(body: Table.Body([
                Table.Row(),
                Table.Row(),
                Table.Row(),
            ]))
            XCTAssertTrue(table.head.isEmpty)
            XCTAssertEqual(3, table.body.childCount)
        }
    }

    func testSetBody() {
        do { // non-empty -> empty
            let source = """
            |x|y|z|
            |-|-|-|
            |1|2|3|
            """
            let document = Document(parsing: source)
            var table = document.child(at: 0) as! Table
            XCTAssertFalse(table.head.isEmpty)
            XCTAssertFalse(table.body.isEmpty)
            table.body.setRows([])
            XCTAssertFalse(table.head.isEmpty)
            XCTAssertTrue(table.body.isEmpty)

            let expectedDump = """
            Document
            └─ Table alignments: |-|-|-|
               ├─ Head
               │  ├─ Cell
               │  │  └─ Text "x"
               │  ├─ Cell
               │  │  └─ Text "y"
               │  └─ Cell
               │     └─ Text "z"
               └─ Body
            """
            XCTAssertEqual(expectedDump, table.root.debugDescription())
        }

        do { // empty -> non-empty
            let source = """
            |x|y|z|
            |-|-|-|
            """
            let document = Document(parsing: source)
            var table = document.child(at: 0) as! Table
            XCTAssertFalse(table.head.isEmpty)
            XCTAssertTrue(table.body.isEmpty)
            table.body.setRows([
                Table.Row([
                    Table.Cell(Text("1")),
                    Table.Cell(Text("2")),
                    Table.Cell(Text("3")),
                ])
            ])
            XCTAssertFalse(table.head.isEmpty)
            XCTAssertFalse(table.body.isEmpty)

            let expectedDump = """
            Document
            └─ Table alignments: |-|-|-|
               ├─ Head
               │  ├─ Cell
               │  │  └─ Text "x"
               │  ├─ Cell
               │  │  └─ Text "y"
               │  └─ Cell
               │     └─ Text "z"
               └─ Body
                  └─ Row
                     ├─ Cell
                     │  └─ Text "1"
                     ├─ Cell
                     │  └─ Text "2"
                     └─ Cell
                        └─ Text "3"
            """
            XCTAssertEqual(expectedDump, table.root.debugDescription())

        }
    }

    func testParse() {
        let source = """
        |x|y|
        |-|-|
        |1|2|
        |3|4|
        """
        let document = Document(parsing: source)
        let expectedDump = """
        Document @1:1-4:6
        └─ Table @1:1-4:6 alignments: |-|-|
           ├─ Head @1:1-1:6
           │  ├─ Cell @1:2-1:3
           │  │  └─ Text @1:2-1:3 "x"
           │  └─ Cell @1:4-1:5
           │     └─ Text @1:4-1:5 "y"
           └─ Body @3:1-4:6
              ├─ Row @3:1-3:6
              │  ├─ Cell @3:2-3:3
              │  │  └─ Text @3:2-3:3 "1"
              │  └─ Cell @3:4-3:5
              │     └─ Text @3:4-3:5 "2"
              └─ Row @4:1-4:6
                 ├─ Cell @4:2-4:3
                 │  └─ Text @4:2-4:3 "3"
                 └─ Cell @4:4-4:5
                    └─ Text @4:4-4:5 "4"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }
}
