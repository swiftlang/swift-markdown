/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import Markdown
import XCTest

class DoxygenCommandParserTests: XCTestCase {
    let parseOptions: ParseOptions = [.parseMinimalDoxygen, .parseBlockDirectives]

    func testParseDiscussion() {
        func assertValidParse(source: String) {
            let document = Document(parsing: source, options: parseOptions)
            XCTAssert(document.child(at: 0) is DoxygenDiscussion)

            let expectedDump = """
            Document
            └─ DoxygenDiscussion
               └─ Paragraph
                  └─ Text "The thing."
            """
            XCTAssertEqual(document.debugDescription(), expectedDump)
        }

        assertValidParse(source: "@discussion The thing.")
        assertValidParse(source: #"\discussion The thing."#)
    }

    func testParseAbstract() {
        func assertValidParse(source: String) {
            let document = Document(parsing: source, options: parseOptions)
            XCTAssert(document.child(at: 0) is DoxygenAbstract)

            let expectedDump = """
            Document
            └─ DoxygenAbstract
               └─ Paragraph
                  └─ Text "The thing."
            """
            XCTAssertEqual(document.debugDescription(), expectedDump)
        }

        assertValidParse(source: "@abstract The thing.")
        assertValidParse(source: #"\abstract The thing."#)
        assertValidParse(source: "@brief The thing.")
        assertValidParse(source: #"\brief The thing."#)
    }

    func testParseNote() {
        func assertValidParse(source: String) {
            let document = Document(parsing: source, options: parseOptions)
            XCTAssert(document.child(at: 0) is DoxygenNote)

            let expectedDump = """
            Document
            └─ DoxygenNote
               └─ Paragraph
                  └─ Text "The thing."
            """
            XCTAssertEqual(document.debugDescription(), expectedDump)
        }

        assertValidParse(source: "@note The thing.")
        assertValidParse(source: #"\note The thing."#)
    }

    func testParseParam() throws {
        let source = """
        @param thing The thing.
        """

        let document = Document(parsing: source, options: parseOptions)
        let param = try XCTUnwrap(document.child(at: 0) as? DoxygenParameter)
        XCTAssertEqual(param.name, "thing")

        let expectedDump = """
        Document
        └─ DoxygenParameter parameter: thing
           └─ Paragraph
              └─ Text "The thing."
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testParseReturns() {
        func assertValidParse(source: String) {
            let document = Document(parsing: source, options: parseOptions)
            XCTAssert(document.child(at: 0) is DoxygenReturns)

            let expectedDump = """
            Document
            └─ DoxygenReturns
               └─ Paragraph
                  └─ Text "The thing."
            """
            XCTAssertEqual(document.debugDescription(), expectedDump)
        }

        assertValidParse(source: "@returns The thing.")
        assertValidParse(source: "@return The thing.")
        assertValidParse(source: "@result The thing.")
        assertValidParse(source: #"\returns The thing."#)
        assertValidParse(source: #"\return The thing."#)
        assertValidParse(source: #"\result The thing."#)
    }

    func testParseParamWithSlash() throws {
        let source = #"""
        \param thing The thing.
        """#

        let document = Document(parsing: source, options: parseOptions)
        let param = try XCTUnwrap(document.child(at: 0) as? DoxygenParameter)
        XCTAssertEqual(param.name, "thing")

        let expectedDump = """
        Document
        └─ DoxygenParameter parameter: thing
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
        └─ DoxygenParameter parameter: thing
           └─ Paragraph
              ├─ Text "The thing."
              ├─ SoftBreak
              └─ Text "This is the thing that is messed with."
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testParseIndentedDescription() {
        let source = """
        @param thing
            The thing.
        """

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = """
        Document
        └─ DoxygenParameter parameter: thing
           └─ Paragraph
              └─ Text "The thing."
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testParseMultilineIndentedDescription() {
        let source = """
        @param thing The thing.
            This is the thing that is messed with.
        """

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = """
        Document
        └─ DoxygenParameter parameter: thing
           └─ Paragraph
              ├─ Text "The thing."
              ├─ SoftBreak
              └─ Text "This is the thing that is messed with."
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }

    func testParseWithIndentedAtSign() {
        let source = """
        Method description.

         @param thing The thing.
            This is the thing that is messed with.
        """

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = """
        Document
        ├─ Paragraph
        │  └─ Text "Method description."
        └─ DoxygenParameter parameter: thing
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
        ├─ DoxygenParameter parameter: thing
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
        ├─ DoxygenParameter parameter: thing
        │  └─ Paragraph
        │     └─ Text "The thing."
        └─ DoxygenParameter parameter: otherThing
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
        ├─ DoxygenParameter parameter: thing
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
        └─ DoxygenParameter parameter: thing
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

        let expectedDump = """
        Document @1:1-2:39
        └─ DoxygenParameter @1:1-2:39 parameter: thing
           └─ Paragraph @1:14-2:39
              ├─ Text @1:14-1:24 "The thing."
              ├─ SoftBreak
              └─ Text @2:1-2:39 "This is the thing that is messed with."
        """
        XCTAssertEqual(document.debugDescription(options: .printSourceLocations), expectedDump)
    }

    func testSourceLocationsWithIndentation() {
        let source = """
        @param thing The thing.
            This is the thing that is messed with.
        """

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = """
        Document @1:1-2:43
        └─ DoxygenParameter @1:1-2:43 parameter: thing
           └─ Paragraph @1:14-2:43
              ├─ Text @1:14-1:24 "The thing."
              ├─ SoftBreak
              └─ Text @2:5-2:43 "This is the thing that is messed with."
        """
        XCTAssertEqual(document.debugDescription(options: .printSourceLocations), expectedDump)
    }

    func testSourceLocationsWithIndentedAtSign() {
        let source = """
        Method description.

         @param thing The thing.
            This is the thing that is messed with.
        """

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = """
        Document @1:1-4:43
        ├─ Paragraph @1:1-1:20
        │  └─ Text @1:1-1:20 "Method description."
        └─ DoxygenParameter @3:2-4:43 parameter: thing
           └─ Paragraph @3:15-4:43
              ├─ Text @3:15-3:25 "The thing."
              ├─ SoftBreak
              └─ Text @4:5-4:43 "This is the thing that is messed with."
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

    func testRunOnDirectivesAllowDoxygenParsing() {
        let source = #"""
        @method doSomethingWithNumber:
        @abstract Some brief description of this method
        @param number Some description of the "number" parameter
        @return Some description of the return value
        @discussion Some longer discussion for this method
        """#

        let document = Document(parsing: source, options: parseOptions)

        let expectedDump = #"""
        Document
        ├─ BlockDirective name: "method"
        ├─ DoxygenAbstract
        │  └─ Paragraph
        │     └─ Text "Some brief description of this method"
        ├─ DoxygenParameter parameter: number
        │  └─ Paragraph
        │     └─ Text "Some description of the “number” parameter"
        ├─ DoxygenReturns
        │  └─ Paragraph
        │     └─ Text "Some description of the return value"
        └─ DoxygenDiscussion
           └─ Paragraph
              └─ Text "Some longer discussion for this method"
        """#
        XCTAssertEqual(document.debugDescription(), expectedDump)
    }
}
