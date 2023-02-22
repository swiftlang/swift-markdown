/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import Markdown
import XCTest

class DoxygenCommandParserTests: XCTestCase {
    let parseOptions: ParseOptions = [.parseMinimalDoxygen, .parseBlockDirectives]

    func testParseParam() throws {
        let source = """
        @param thing The thing.
        """

        let document = Document(parsing: source, options: parseOptions)
        let param = try XCTUnwrap(document.child(at: 0) as? DoxygenParam)
        XCTAssertEqual(param.name, "thing")

        let expectedDump = """
        Document
        └─ DoxygenParam parameter: thing
           └─ Paragraph
              └─ Text "The thing."
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testParseParamWithSlash() throws {
        let source = #"""
        \param thing The thing.
        """#

        let document = Document(parsing: source, options: parseOptions)
        let param = try XCTUnwrap(document.child(at: 0) as? DoxygenParam)
        XCTAssertEqual(param.name, "thing")

        let expectedDump = """
        Document
        └─ DoxygenParam parameter: thing
           └─ Paragraph
              └─ Text "The thing."
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testParseMultilineDescription() {
        let source = """
        @param thing The thing.
        This is the thing that is messed with.
        """

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = """
        Document
        └─ DoxygenParam parameter: thing
           └─ Paragraph
              ├─ Text "The thing."
              ├─ SoftBreak
              └─ Text "This is the thing that is messed with."
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testBreakDescriptionWithBlankLine() {
        let source = """
        @param thing The thing.

        Messes with the thing.
        """

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = """
        Document
        ├─ DoxygenParam parameter: thing
        │  └─ Paragraph
        │     └─ Text "The thing."
        └─ Paragraph
           └─ Text "Messes with the thing."
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testBreakDescriptionWithOtherCommand() {
        let source = """
        Messes with the thing.

        @param thing The thing.
        @param otherThing The other thing.
        """

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = """
        Document
        ├─ Paragraph
        │  └─ Text "Messes with the thing."
        ├─ DoxygenParam parameter: thing
        │  └─ Paragraph
        │     └─ Text "The thing."
        └─ DoxygenParam parameter: otherThing
           └─ Paragraph
              └─ Text "The other thing."
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testBreakDescriptionWithBlockDirective() {
        let source = """
        Messes with the thing.

        @param thing The thing.
        @Comment {
            This is supposed to be different from the above command.
        }
        """

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = """
        Document
        ├─ Paragraph
        │  └─ Text "Messes with the thing."
        ├─ DoxygenParam parameter: thing
        │  └─ Paragraph
        │     └─ Text "The thing."
        └─ BlockDirective name: "Comment"
           └─ Paragraph
              └─ Text "This is supposed to be different from the above command."
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testCommandBreaksParagraph() {
        let source = """
        This is a paragraph.
        @param thing The thing.
        """

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = """
        Document
        ├─ Paragraph
        │  └─ Text "This is a paragraph."
        └─ DoxygenParam parameter: thing
           └─ Paragraph
              └─ Text "The thing."
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testSourceLocations() {
        let source = """
        @param thing The thing.
        This is the thing that is messed with.
        """

        let document = Document(parsing: source, options: parseOptions)

        // FIXME: The source location for the first description line is wrong
        let expectedDump = """
        Document @1:1-2:39
        └─ DoxygenParam @1:1-2:39 parameter: thing
           └─ Paragraph @1:14-2:39
              ├─ Text @1:14-1:24 "The thing."
              ├─ SoftBreak
              └─ Text @2:1-2:39 "This is the thing that is messed with."
        """
        XCTAssertEqual(document.debugDescription(options: .printSourceLocations), expectedDump)
    }

    func testDoesNotParseWithoutOption() {
        do {
            let source = """
            @param thing The thing.
            """

            let document = Document(parsing: source, options: .parseBlockDirectives)

            let expectedDump = """
            Document
            └─ BlockDirective name: "param"
            """
            XCTAssertEqual(document.debugDescription(), expectedDump)
        }

        do {
            let source = """
            @param thing The thing.
            """

            let document = Document(parsing: source)

            let expectedDump = """
            Document
            └─ Paragraph
               └─ Text "@param thing The thing."
            """
            XCTAssertEqual(document.debugDescription(), expectedDump)
        }
    }

    func testDoesNotParseInsideBlockDirective() {
        let source = """
        @Comment {
            @param thing The thing.
        }
        """

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = """
        Document
        └─ BlockDirective name: "Comment"
           └─ BlockDirective name: "param"
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testDoesNotParseInsideCodeBlock() {
        do {
            let source = """
            ```
            @param thing The thing.
            ```
            """

            let document = Document(parsing: source, options: parseOptions)

            let expectedDump = """
            Document
            └─ CodeBlock language: none
               @param thing The thing.
            """
            XCTAssertEqual(document.debugDescription(), expectedDump)
        }

        do {
            let source = """
            Paragraph to set indentation.

                @param thing The thing.
            """

            let document = Document(parsing: source, options: parseOptions)

            let expectedDump = """
            Document
            ├─ Paragraph
            │  └─ Text "Paragraph to set indentation."
            └─ CodeBlock language: none
               @param thing The thing.
            """
            XCTAssertEqual(document.debugDescription(), expectedDump)
        }
    }

    func testDoesNotParseUnknownCommand() {
        let source = #"""
        \unknown
        """#

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = #"""
        Document
        └─ Paragraph
           └─ Text "\unknown"
        """#
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }
}
