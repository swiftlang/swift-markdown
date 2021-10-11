/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import Markdown
import XCTest

fileprivate extension RandomAccessCollection where Element == DirectiveArgument {
    /// Look for an argument named `name` or log an XCTest failure.
    subscript<S: StringProtocol>(_ name: S, file: StaticString = #filePath, line: UInt = #line) -> DirectiveArgument? {
        guard let found = self.first(where: {
            $0.name == name
        }) else {
            XCTFail("Expected argument named \(name) but it was not found", file: file, line: line)
            return nil
        }
        return found
    }
}

class BlockDirectiveArgumentParserTests: XCTestCase {
    func testNone() throws {
        let source = "@Outer"
        let document = BlockDirectiveParser.parse(source, source: nil)
        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertEqual("Outer", directive.name)
        XCTAssertEqual(SourceLocation(line: 1, column: 1, source: nil)..<SourceLocation(line: 1, column: 6, source: nil), directive.nameRange)

        XCTAssertTrue(directive.argumentText.isEmpty)
        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)
        XCTAssertTrue(arguments.isEmpty)
    }

    func testEmpty() throws {
        let source = "@Outer()"

        let document = BlockDirectiveParser.parse(source, source: nil)

        let directive = document.child(at: 0) as! BlockDirective
        XCTAssertTrue(directive.argumentText.isEmpty)
        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)
        XCTAssertTrue(arguments.isEmpty)
    }

    func testOne() throws {
        let source = "@Outer(x: 1)"

        let document = BlockDirectiveParser.parse(source, source: nil)

        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)
        XCTAssertEqual(1, arguments.count)

        arguments["x"].map { x in
            XCTAssertEqual("x", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 9, source: nil), x.nameRange)
            XCTAssertEqual(x.value, "1")
            XCTAssertEqual(SourceLocation(line: 1, column: 11, source: nil)..<SourceLocation(line: 1, column: 12, source: nil), x.valueRange)
        }
    }

    func testTwoOnOneLine() throws {
        let source = "@Outer(x: 1, y: 2)"

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertEqual(1, directive.argumentText.segments.count)
        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)
        XCTAssertEqual(2, arguments.count)

        arguments["x"].map { x in
            XCTAssertEqual("x", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 9, source: nil), x.nameRange)
            XCTAssertEqual(x.value, "1")
            XCTAssertEqual(SourceLocation(line: 1, column: 11, source: nil)..<SourceLocation(line: 1, column: 12, source: nil), x.valueRange)
        }

        arguments["y"].map { y in
            XCTAssertEqual("y", y.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 14, source: nil)..<SourceLocation(line: 1, column: 15, source: nil), y.nameRange)
            XCTAssertEqual(y.value, "2")
            XCTAssertEqual(SourceLocation(line: 1, column: 17, source: nil)..<SourceLocation(line: 1, column: 18, source: nil), y.valueRange)
        }
    }

    func testOneOnEachLine() throws {
        let source = """
        @Outer(x: 1,
               y: 2)
        """

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertEqual(2, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)
        XCTAssertEqual(2, arguments.count)

        arguments["x"].map { x in
            XCTAssertEqual("x", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 9, source: nil), x.nameRange)
            XCTAssertEqual(x.value, "1")
            XCTAssertEqual(SourceLocation(line: 1, column: 11, source: nil)..<SourceLocation(line: 1, column: 12, source: nil), x.valueRange)
        }

        arguments["y"].map { y in
            XCTAssertEqual("y", y.name)
            XCTAssertEqual(SourceLocation(line: 2, column: 8, source: nil)..<SourceLocation(line: 2, column: 9, source: nil), y.nameRange)
            XCTAssertEqual(y.value, "2")
            XCTAssertEqual(SourceLocation(line: 2, column: 11, source: nil)..<SourceLocation(line: 2, column: 12, source: nil), y.valueRange)
        }
    }

    /// Test that when a colon is missing in an argument,
    /// the parser skips until the next comma `,` or until the end
    /// of the line.
    func testMissingColonOne() throws {
        let source = "@Outer(missingColon true, x: 1)"

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertEqual([.missingExpectedCharacter(":", location: .init(line: 1, column: 20, source: nil))],
                       parseErrors)

        XCTAssertEqual(2, arguments.count)

        arguments["missingColon"].map { missingColon in
            XCTAssertEqual("missingColon", missingColon.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 20, source: nil), missingColon.nameRange)
            XCTAssertEqual(missingColon.value, "true")
            XCTAssertEqual(SourceLocation(line: 1, column: 21, source: nil)..<SourceLocation(line: 1, column: 25, source: nil), missingColon.valueRange)
        }

        arguments["x"].map { x in
            XCTAssertEqual("x", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 27, source: nil)..<SourceLocation(line: 1, column: 28, source: nil), x.nameRange)
            XCTAssertEqual(x.value, "1")
            XCTAssertEqual(SourceLocation(line: 1, column: 30, source: nil)..<SourceLocation(line: 1, column: 31, source: nil), x.valueRange)
        }
    }

    func testMissingColonTwo() throws {
        let source = "@Outer(x 1, y 2)"

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertEqual([
            .missingExpectedCharacter(":", location: .init(line: 1, column: 9, source: nil)),
            .missingExpectedCharacter(":", location: .init(line: 1, column: 14, source: nil))
        ], parseErrors)

        XCTAssertEqual(2, arguments.count)

        arguments["x"].map { x in
            XCTAssertEqual("x", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 9, source: nil), x.nameRange)
            XCTAssertEqual(x.value, "1")
            XCTAssertEqual(SourceLocation(line: 1, column: 10, source: nil)..<SourceLocation(line: 1, column: 11, source: nil), x.valueRange)
        }

        arguments["y"].map { y in
            XCTAssertEqual("y", y.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 13, source: nil)..<SourceLocation(line: 1, column: 14, source: nil), y.nameRange)
            XCTAssertEqual(y.value, "2")
            XCTAssertEqual(SourceLocation(line: 1, column: 15, source: nil)..<SourceLocation(line: 1, column: 16, source: nil), y.valueRange)
        }
    }

    func testMissingCommaBetweenTwo() throws {
        let source = "@Outer(x: 1 y: 2)"

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertEqual([
            .missingExpectedCharacter(",", location: .init(line: 1, column: 12, source: nil))
        ], parseErrors)

        XCTAssertEqual(2, arguments.count)

        arguments["x"].map { x in
            XCTAssertEqual("x", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 9, source: nil), x.nameRange)
            XCTAssertEqual(x.value, "1")
            XCTAssertEqual(SourceLocation(line: 1, column: 11, source: nil)..<SourceLocation(line: 1, column: 12, source: nil), x.valueRange)
        }

        arguments["y"].map { y in
            XCTAssertEqual("y", y.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 13, source: nil)..<SourceLocation(line: 1, column: 14, source: nil), y.nameRange)
            XCTAssertEqual(y.value, "2")
            XCTAssertEqual(SourceLocation(line: 1, column: 16, source: nil)..<SourceLocation(line: 1, column: 17, source: nil), y.valueRange)
        }
    }

    func testMissingCommaEnd() throws {
        let source = """
        @Outer(x: 1
               y: 2)
        """

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertEqual(2, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertEqual([.missingExpectedCharacter(",", location: .init(line: 1, column: 12, source: nil))], parseErrors)

        XCTAssertEqual(2, arguments.count)

        arguments["x"].map { x in
            XCTAssertEqual("x", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 9, source: nil), x.nameRange)
            XCTAssertEqual(x.value, "1")
            XCTAssertEqual(SourceLocation(line: 1, column: 11, source: nil)..<SourceLocation(line: 1, column: 12, source: nil), x.valueRange)
        }

        arguments["y"].map { y in
            XCTAssertEqual("y", y.name)
            XCTAssertEqual(SourceLocation(line: 2, column: 8, source: nil)..<SourceLocation(line: 2, column: 9, source: nil), y.nameRange)
            XCTAssertEqual(y.value, "2")
            XCTAssertEqual(SourceLocation(line: 2, column: 11, source: nil)..<SourceLocation(line: 2, column: 12, source: nil), y.valueRange)
        }
    }

    func testMissingOpenCurly() throws {
        let source = """
        @Outer(x: 1)
          Not a part of `Outer`.
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)

        arguments["x"].map { x in
            XCTAssertEqual("x", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 9, source: nil), x.nameRange)
            XCTAssertEqual(x.value, "1")
            XCTAssertEqual(SourceLocation(line: 1, column: 11, source: nil)..<SourceLocation(line: 1, column: 12, source: nil), x.valueRange)
        }

        let expectedDump = """
        Document @1:1-3:4
        ├─ BlockDirective @1:1-1:8 name: "Outer"
        │  ├─ Argument text segments:
        │  |    @1:8-1:12: "x: 1"
        └─ Paragraph @2:3-3:2
           ├─ Text @2:3-2:17 "Not a part of "
           ├─ InlineCode @2:17-2:24 `Outer`
           ├─ Text @2:24-2:25 "."
           ├─ SoftBreak
           └─ Text @3:3-3:4 "}"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    func testNoCommaOrColon() throws {
        let source = "@Outer(x 1 y 2)"

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertEqual(2, arguments.count)

        arguments["x"].map { x in
            XCTAssertEqual("x", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 9, source: nil), x.nameRange)
            XCTAssertEqual(x.value, "1")
            XCTAssertEqual(SourceLocation(line: 1, column: 10, source: nil)..<SourceLocation(line: 1, column: 11, source: nil), x.valueRange)
        }

        arguments["y"].map { y in
            XCTAssertEqual("y", y.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 12, source: nil)..<SourceLocation(line: 1, column: 13, source: nil), y.nameRange)
            XCTAssertEqual(y.value, "2")
            XCTAssertEqual(SourceLocation(line: 1, column: 14, source: nil)..<SourceLocation(line: 1, column: 15, source: nil), y.valueRange)
        }
    }

    func testNoPunctuationOnFirstLine() throws {
        let source = "@Outer x 1 y 2"

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertTrue(directive.argumentText.isEmpty)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(arguments.isEmpty)
        let expectedDump = """
        Document @1:1-1:7
        └─ BlockDirective @1:1-1:7 name: "Outer"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    func testEscapedValue() {
        let source = "@Outer(x: ab\\)c)"

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective
        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)

        XCTAssertEqual(1, arguments.count)

        arguments["x"].map { x in
            XCTAssertEqual("x", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 9, source: nil), x.nameRange)
            XCTAssertEqual("ab\\)c", x.value)
            XCTAssertEqual(SourceLocation(line: 1, column: 11, source: nil)..<SourceLocation(line: 1, column: 16, source: nil), x.valueRange)
        }
    }

    func testDoubleEscape() {
        let source = "@Outer(x: ab\\\\c)"

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective
        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)

        XCTAssertEqual(1, arguments.count)

        arguments["x"].map { x in
            XCTAssertEqual("x", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 9, source: nil), x.nameRange)
            XCTAssertEqual("ab\\\\c", x.value)
            XCTAssertEqual(SourceLocation(line: 1, column: 11, source: nil)..<SourceLocation(line: 1, column: 16, source: nil), x.valueRange)
        }
    }

    func testRangeAdjustment() {
        let source = """
        @Outer {
          - A
          - *B*
            - **C**
          @Inner {
            Some more stuff.

                Confusing indented code block.
          }
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = """
        Document @1:1-10:2
        └─ BlockDirective @1:1-10:2 name: "Outer"
           ├─ UnorderedList @2:3-4:12
           │  ├─ ListItem @2:3-2:6
           │  │  └─ Paragraph @2:5-2:6
           │  │     └─ Text @2:5-2:6 "A"
           │  └─ ListItem @3:3-4:12
           │     ├─ Paragraph @3:5-3:8
           │     │  └─ Emphasis @3:5-3:8
           │     │     └─ Text @3:6-3:7 "B"
           │     └─ UnorderedList @4:5-4:12
           │        └─ ListItem @4:5-4:12
           │           └─ Paragraph @4:7-4:12
           │              └─ Strong @4:7-4:12
           │                 └─ Text @4:9-4:10 "C"
           └─ BlockDirective @5:3-9:4 name: "Inner"
              ├─ Paragraph @6:5-6:21
              │  └─ Text @6:5-6:21 "Some more stuff."
              └─ CodeBlock @8:9-8:39 language: none
                 Confusing indented code block.
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    func testDontOpenBlockDirectivesInCodeBlocks() {
        let source = """
        @Outer {
            Starting the directive.

                @notABlockDirective
                func foo() { /* A code block of Swift */ }

        @Inner {
          ```
          @notABlockDirective
          func foo() { /* A code block of Swift */ }
          ```
        }
         @Inner {
           @InnerInner
             Starting the directive.

                 @notABlockDirective
         }
          @Inner {
            @InnerInner
              Starting the directive.

                  @notABlockDirective
          }
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = """
        Document @1:1-25:2
        └─ BlockDirective @1:1-25:2 name: "Outer"
           ├─ Paragraph @2:5-2:28
           │  └─ Text @2:5-2:28 "Starting the directive."
           ├─ CodeBlock @4:9-5:51 language: none
           │  @notABlockDirective
           │  func foo() { /* A code block of Swift */ }
           ├─ BlockDirective @7:1-12:2 name: "Inner"
           │  └─ CodeBlock @8:3-11:6 language: none
           │     @notABlockDirective
           │     func foo() { /* A code block of Swift */ }
           ├─ BlockDirective @13:2-18:3 name: "Inner"
           │  ├─ BlockDirective @14:4-14:15 name: "InnerInner"
           │  ├─ Paragraph @15:6-15:29
           │  │  └─ Text @15:6-15:29 "Starting the directive."
           │  └─ CodeBlock @17:8-17:29 language: none
           │       @notABlockDirective
           └─ BlockDirective @19:3-24:4 name: "Inner"
              ├─ BlockDirective @20:5-20:16 name: "InnerInner"
              ├─ Paragraph @21:7-21:30
              │  └─ Text @21:7-21:30 "Starting the directive."
              └─ CodeBlock @23:9-23:30 language: none
                   @notABlockDirective
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    func testDontCloseBlockDirectivesInCodeBlocks() {
        let source = """
        @Outer {
            Starting the directive.

                } a code block; doesn't close `Outer`.
        }

        @Outer {
          ```
          } a code block; doesn't close `Outer`.
          ```
        }

        @Outer {
          @Inner {
            Starting the directive.

                } a code block; doesn't close `Inner`
          }
        }

        @Outer {
          @Inner {
            ```
            } a code block; doesn't close `Inner`
            ```
          }
        }

        @Outer {
          @Inner {
            }
          }
        """

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = """
        Document @1:1-32:4
        ├─ BlockDirective @1:1-5:2 name: "Outer"
        │  ├─ Paragraph @2:5-2:28
        │  │  └─ Text @2:5-2:28 "Starting the directive."
        │  └─ CodeBlock @4:9-4:47 language: none
        │     } a code block; doesn't close `Outer`.
        ├─ BlockDirective @7:1-11:2 name: "Outer"
        │  └─ CodeBlock @8:3-10:6 language: none
        │     } a code block; doesn't close `Outer`.
        ├─ BlockDirective @13:1-19:2 name: "Outer"
        │  └─ BlockDirective @14:3-18:4 name: "Inner"
        │     ├─ Paragraph @15:5-15:28
        │     │  └─ Text @15:5-15:28 "Starting the directive."
        │     └─ CodeBlock @17:9-17:46 language: none
        │        } a code block; doesn't close `Inner`
        ├─ BlockDirective @21:1-27:2 name: "Outer"
        │  └─ BlockDirective @22:3-26:4 name: "Inner"
        │     └─ CodeBlock @23:5-25:8 language: none
        │        } a code block; doesn't close `Inner`
        └─ BlockDirective @29:1-32:4 name: "Outer"
           └─ BlockDirective @30:3-31:6 name: "Inner"
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    /// Ensures that having a blank line as the first line of a block directive does not interfere with indentation calculations.
    func testBlankFirstLineInDirective() {
        let source = """
        @Outer {

          Here's some block-directive content.

        }
        """

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = """
        Document @1:1-5:2
        └─ BlockDirective @1:1-5:2 name: "Outer"
           └─ Paragraph @3:3-3:39
              └─ Text @3:3-3:39 "Here’s some block-directive content."
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    /// Ensures that using four spaces of indentation inside a block directive does not open a code block.
    func testFourSpaceIndent() {
        let source = """
        @Outer {
            This is not a code block.
        }
        """

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = """
        Document @1:1-3:2
        └─ BlockDirective @1:1-3:2 name: "Outer"
           └─ Paragraph @2:5-2:30
              └─ Text @2:5-2:30 "This is not a code block."
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }

    /// Ensures that indentation calculations correctly transfer into CommonMark when indenting a block
    /// directive's content by four spaces.
    func testFourSpaceIndentWithExtraContent() {
        let source = """
        @Outer {
            This is not a code block.

            - This is why it's not a code block:
              - By using four spaces of indentation,
                we can use most editors' default
                of indenting by four spaces without
                corrupting users' content.
        }
        """

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = """
        Document @1:1-9:2
        └─ BlockDirective @1:1-9:2 name: "Outer"
           ├─ Paragraph @2:5-2:30
           │  └─ Text @2:5-2:30 "This is not a code block."
           └─ UnorderedList @4:5-8:35
              └─ ListItem @4:5-8:35
                 ├─ Paragraph @4:7-4:41
                 │  └─ Text @4:7-4:41 "This is why it’s not a code block:"
                 └─ UnorderedList @5:7-8:35
                    └─ ListItem @5:7-8:35
                       └─ Paragraph @5:9-8:35
                          ├─ Text @5:9-5:45 "By using four spaces of indentation,"
                          ├─ SoftBreak
                          ├─ Text @6:9-6:41 "we can use most editors’ default"
                          ├─ SoftBreak
                          ├─ Text @7:9-7:44 "of indenting by four spaces without"
                          ├─ SoftBreak
                          └─ Text @8:9-8:35 "corrupting users’ content."
        """
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
    }
    
    /// This test verifies the case where there are unescaped double quotes in an argument value.
    /// rdar://72051229
    func testMissingCharacterAndUnexpectedCharacterErrors() throws {
        let source = """
        @Dir(x: "Value "123", other text.")
        """

        let document = BlockDirectiveParser.parse(source, source: nil)

        let directive = document.child(at: 0) as! BlockDirective

        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertEqual(arguments["x"]?.value, "Value ")
        
        XCTAssertEqual(parseErrors.count, 2)
        guard parseErrors.count == 2 else {
            XCTFail("Did not emit the correct amount of parsing errors")
            return
        }
        
        // Verify the missing expected ":" error.
        switch parseErrors[0] {
            case .missingExpectedCharacter(let char, location: let location):
                XCTAssertEqual(char, ":")
                XCTAssertEqual(location.column, 21)
            default:
                XCTFail("Unexpected parsing error.")
        }

        // Verify the unexpected "," error.
        switch parseErrors[1] {
            case .unexpectedCharacter(let char, location: let location):
                XCTAssertEqual(char, ",")
                XCTAssertEqual(location.column, 22)
            default:
                XCTFail("Unexpected parsing error.")
        }
    }

    func testCloseParenInDirectiveArgument() {
        let source = """
        @Outer(name: "Chapter 1 (out of 2)") {
          This is a `Chapter`.
        }
        """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = """
        Document @1:1-3:2
        └─ BlockDirective @1:1-3:2 name: "Outer"
           ├─ Argument text segments:
           |    @1:8-1:36: "name: \\"Chapter 1 (out of 2)\\""
           └─ Paragraph @2:3-2:23
              ├─ Text @2:3-2:13 "This is a "
              ├─ InlineCode @2:13-2:22 `Chapter`
              └─ Text @2:22-2:23 "."
        """
        
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
        
        let directive = document.child(at: 0) as! BlockDirective
        
        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)
        XCTAssertEqual(1, arguments.count)
        
        arguments["name"].map { x in
            XCTAssertEqual("name", x.name)
            XCTAssertEqual(x.value, "Chapter 1 (out of 2)")
        }
    }
    
    func testQuotesInStrings() {
        let source = """
        @Outer(name: "\\"(hello)\\"") {
          This is a test.
        }
        """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = """
        Document @1:1-3:2
        └─ BlockDirective @1:1-3:2 name: "Outer"
           ├─ Argument text segments:
           |    @1:8-1:27: "name: \\"\\\\\\"(hello)\\\\\\"\\""
           └─ Paragraph @2:3-2:18
              └─ Text @2:3-2:18 "This is a test."
        """
        
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
        
        let directive = document.child(at: 0) as! BlockDirective
        
        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)
        XCTAssertEqual(1, arguments.count)
        
        arguments["name"].map { x in
            XCTAssertEqual("name", x.name)
            XCTAssertEqual(x.value, "\\\"(hello)\\\"")
        }
    }
    
    func testEmptyStringArgument() {
        // make sure that block directives where an argument is an empty string still show the argument after parsing
        let source = """
        @Outer(name: "") {
          This is a test.
        }
        """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = """
        Document @1:1-3:2
        └─ BlockDirective @1:1-3:2 name: "Outer"
           ├─ Argument text segments:
           |    @1:8-1:16: "name: \\"\\""
           └─ Paragraph @2:3-2:18
              └─ Text @2:3-2:18 "This is a test."
        """
        
        XCTAssertEqual(expectedDump, document.debugDescription(options: .printSourceLocations))
        
        let directive = document.child(at: 0) as! BlockDirective
        
        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)
        XCTAssertEqual(1, arguments.count)
        
        arguments["name"].map { x in
            XCTAssertEqual("name", x.name)
            XCTAssertEqual(x.value, "")
        }
    }
}
