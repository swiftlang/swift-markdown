/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
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
        ├─ BlockDirective @1:1-1:13 name: "Outer"
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
    
    func testUnlabeledOnlyArgument() {
        let source = "@Outer(unlabeledArgumentValue)"

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective
        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)

        XCTAssertEqual(1, arguments.count)

        arguments[""].map { x in
            XCTAssertEqual("", x.name)
            XCTAssertEqual(nil, x.nameRange)
            XCTAssertEqual("unlabeledArgumentValue", x.value)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 30, source: nil), x.valueRange)
        }
    }
    
    func testUnlabeledQuotedOnlyArgument(){
        let source = "@Outer(\"Unlabeled argument value\")"

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective
        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)

        XCTAssertEqual(1, arguments.count)

        arguments[""].map { x in
            XCTAssertEqual("", x.name)
            XCTAssertEqual(nil, x.nameRange)
            XCTAssertEqual("Unlabeled argument value", x.value)
            XCTAssertEqual(SourceLocation(line: 1, column: 9, source: nil)..<SourceLocation(line: 1, column: 33, source: nil), x.valueRange)
        }
    }
    
    func testFirstArgumentWithoutName() {
        let source = "@Outer(unlabeledArgumentValue, label: value)"

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective
        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)

        XCTAssertEqual(2, arguments.count)

        arguments[""].map { x in
            XCTAssertEqual("", x.name)
            XCTAssertEqual(nil, x.nameRange)
            XCTAssertEqual("unlabeledArgumentValue", x.value)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 30, source: nil), x.valueRange)
        }
    }
    
    func testSecondArgumentWithoutName() throws {
        let source = "@Outer(label: value, unlabeledArgumentValue)"

        let document = Document(parsing: source, options: .parseBlockDirectives)

        let directive = document.child(at: 0) as! BlockDirective
        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertEqual(parseErrors.count, 1)
       
        XCTAssertEqual([.missingExpectedCharacter(":", location: .init(line: 1, column: 44, source: nil))], parseErrors)

        XCTAssertEqual(1, arguments.count)

        arguments["label"].map { x in
            XCTAssertEqual("label", x.name)
            XCTAssertEqual(SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 13, source: nil), x.nameRange)
            XCTAssertEqual("value", x.value)
            XCTAssertEqual(SourceLocation(line: 1, column: 15, source: nil)..<SourceLocation(line: 1, column: 20, source: nil), x.valueRange)
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
    
    
    func testSingleLineRange() {
        let source = """
        @Image(source: 1.png, alt: "hello")
        """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        XCTAssertEqual(1, directive.argumentText.segments.count)

        var parseErrors = [DirectiveArgumentText.ParseError]()
        let arguments = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)
        XCTAssertTrue(parseErrors.isEmpty)
        
        XCTAssertEqual(arguments.count,2)
        arguments["source"].map { x in
            XCTAssertEqual(x.name, "source")
            XCTAssertEqual(x.value, "1.png")
        }
        arguments["alt"].map { x in
            XCTAssertEqual(x.name, "alt")
            XCTAssertEqual(x.value, "hello")
        }
        
        let expectedDump = #"""
        Document @1:1-1:36
        └─ BlockDirective @1:1-1:36 name: "Image"
           ├─ Argument text segments:
           |    @1:8-1:35: "source: 1.png, alt: \"hello\""
        """#
        XCTAssertEqual(document.debugDescription(options: .printSourceLocations), expectedDump)
    }
    
    func testSingleLineMissingCloseParenthesis() {
        let source = """
        @Image(source: 1.png,
        alt: "hello"
        @Image(source: 2.png, alt: "hello2")
        """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = #"""
        Document @1:1-3:37
        ├─ BlockDirective @1:1-2:13 name: "Image"
        │  ├─ Argument text segments:
        │  |    @1:8-1:22: "source: 1.png,"
        │  |    @2:1-2:13: "alt: \"hello\""
        └─ BlockDirective @3:1-3:37 name: "Image"
           ├─ Argument text segments:
           |    @3:8-3:36: "source: 2.png, alt: \"hello2\""
        """#
        XCTAssertEqual(document.debugDescription(options: .printSourceLocations), expectedDump)
    }
    
    func testSingleLineOnlyOpenParenthesis() {
        let source = """
        @Image(
        @Image(source: 2.png, alt: "hello2")
        """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = #"""
        Document @1:1-2:37
        ├─ BlockDirective @1:1-1:8 name: "Image"
        └─ BlockDirective @2:1-2:37 name: "Image"
           ├─ Argument text segments:
           |    @2:8-2:36: "source: 2.png, alt: \"hello2\""
        """#
        XCTAssertEqual(document.debugDescription(options: .printSourceLocations), expectedDump)
    }
    
    func testSingleLineMissingParenthesis() {
        let source = """
        @Image
        @Image(source: 2.png, alt: "hello2")
        """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let expectedDump = #"""
        Document @1:1-2:37
        ├─ BlockDirective @1:1-1:7 name: "Image"
        └─ BlockDirective @2:1-2:37 name: "Image"
           ├─ Argument text segments:
           |    @2:8-2:36: "source: 2.png, alt: \"hello2\""
        """#
        XCTAssertEqual(document.debugDescription(options: .printSourceLocations), expectedDump)
    }
    
    func testSingleLineDirective() {
        let source = """
        @xx { yy }
        @xx { yy } zz }
        @xx { yy
            z
        }
        Hello
        """
        let document = Document(parsing: source, options: [.parseBlockDirectives])
        let expectedDump = #"""
        Document @1:1-6:6
        ├─ BlockDirective @1:1-1:11 name: "xx"
        │  └─ Paragraph @1:7-1:9
        │     └─ Text @1:7-1:9 "yy"
        ├─ BlockDirective @2:1-2:16 name: "xx"
        │  └─ Paragraph @2:7-2:14
        │     └─ Text @2:7-2:14 "yy } zz"
        ├─ BlockDirective @3:1-5:2 name: "xx"
        │  └─ Paragraph @4:5-4:6
        │     └─ Text @4:5-4:6 "z"
        └─ Paragraph @6:1-6:6
           └─ Text @6:1-6:6 "Hello"
        """#
        XCTAssertEqual(document.debugDescription(options: .printSourceLocations), expectedDump)
    }

    func testSingleLineDirectiveWithTrailingWhitespace() {
        let source = """
        @blah { content }\(" ")
        @blah {
            content
        }
        """
        let document = Document(parsing: source, options: [.parseBlockDirectives])
        
        let expectedDump = #"""
        Document @1:1-4:2
        ├─ BlockDirective @1:1-1:19 name: "blah"
        │  └─ Paragraph @1:9-1:17
        │     └─ Text @1:9-1:16 "content"
        └─ BlockDirective @2:1-4:2 name: "blah"
           └─ Paragraph @3:5-3:12
              └─ Text @3:5-3:12 "content"
        """#
        XCTAssertEqual(document.debugDescription(options: .printSourceLocations), expectedDump)
    }

    func testSingleLineDirectiveWithTrailingContent() {
        let source = """
        @blah { content }
        content
        """
        let document = Document(parsing: source, options: [.parseBlockDirectives])
        let expectedDump = #"""
        Document @1:1-2:8
        ├─ BlockDirective @1:1-1:18 name: "blah"
        │  └─ Paragraph @1:9-1:16
        │     └─ Text @1:9-1:16 "content"
        └─ Paragraph @2:1-2:8
           └─ Text @2:1-2:8 "content"
        """#
        XCTAssertEqual(document.debugDescription(options: .printSourceLocations), expectedDump)
    }
    
    func testParsingTreeDumpFollowedByDirective() {
        let source = """
        Document
        ├─ Heading level: 1
        │  └─ Text "Title"
        @Comment { Line c This is a single-line comment }
        """
        let documentation = Document(parsing: source, options: .parseBlockDirectives)
        let expected = """
        Document
        ├─ Paragraph
        │  ├─ Text "Document"
        │  ├─ SoftBreak
        │  ├─ Text "├─ Heading level: 1"
        │  ├─ SoftBreak
        │  └─ Text "│  └─ Text “Title”"
        └─ BlockDirective name: "Comment"
           └─ Paragraph
              └─ Text "Line c This is a single-line comment"
        """
        XCTAssertEqual(expected, documentation.debugDescription())
    }
    
    func testParsingDirectiveArgumentsWithWhitespaceBeforeDirective() throws {
        struct ExpectedArgumentInfo {
            var line: Int
            let name: String
            var nameRange: Range<Int>
            let value: String
            var valueRange: Range<Int>
        }
        
        func assertDirectiveArguments(
            _ expectedArguments: ExpectedArgumentInfo...,
            parsing content: String,
            file: StaticString = #file,
            line: UInt = #line
        ) throws {
            func substring(with range: SourceRange) -> String {
                let line = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)[range.lowerBound.line - 1]
                let startIndex = line.utf8.index(line.utf8.startIndex, offsetBy: range.lowerBound.column - 1)
                let endIndex = line.utf8.index(line.utf8.startIndex, offsetBy: range.upperBound.column - 1)
                return String(line[startIndex ..< endIndex])
            }
            
            let source = URL(fileURLWithPath: "/test-file-location")
            let document = Document(parsing: content, source: source, options: .parseBlockDirectives)
            let directive = try XCTUnwrap(document.children.compactMap({ $0 as? BlockDirective }).first, file: file, line: line)
            let arguments = directive.argumentText.parseNameValueArguments()
            XCTAssertEqual(arguments.count, expectedArguments.count, file: file, line: line)
            for expectedArgument in expectedArguments {
                let argument = try XCTUnwrap(arguments[expectedArgument.name], file: file, line: line)
                
                XCTAssertEqual(expectedArgument.name, argument.name, file: file, line: line)
                XCTAssertEqual(
                    argument.nameRange,
                    SourceLocation(line: expectedArgument.line, column: expectedArgument.nameRange.lowerBound, source: source) ..< SourceLocation(line: expectedArgument.line, column: expectedArgument.nameRange.upperBound, source: source),
                    file: file, 
                    line: line
                )
                XCTAssertEqual(expectedArgument.name, argument.nameRange.map(substring(with:)), file: file, line: line)
                
                XCTAssertEqual(expectedArgument.value, argument.value, file: file, line: line)
                XCTAssertEqual(
                    argument.valueRange,
                    SourceLocation(line: expectedArgument.line, column: expectedArgument.valueRange.lowerBound, source: source) ..< SourceLocation(line: expectedArgument.line, column: expectedArgument.valueRange.upperBound, source: source),
                    file: file, 
                    line: line
                )
                XCTAssertEqual(expectedArgument.value, argument.valueRange.map(substring(with:)), file: file, line: line)
            }
        }
        
        // One argument
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 1, name: "firstArgument", nameRange: 16 ..< 29, value: "firstValue", valueRange: 31 ..< 41),
            parsing: "@DirectiveName(firstArgument: firstValue)"
        )
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 2, name: "firstArgument", nameRange: 16 ..< 29, value: "firstValue", valueRange: 31 ..< 41),
            parsing: """
            
            @DirectiveName(firstArgument: firstValue)
            """
        )
        
        // Argument on single line
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 1, name: "firstArgument", nameRange: 17 ..< 30, value: "firstValue", valueRange: 31 ..< 41),
            ExpectedArgumentInfo(line: 1, name: "secondArgument", nameRange: 44 ..< 58, value: "secondValue", valueRange: 62 ..< 73),
            parsing: "@DirectiveName( firstArgument:firstValue ,\tsecondArgument: \t secondValue)"
        )
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 2, name: "firstArgument", nameRange: 17 ..< 30, value: "firstValue", valueRange: 31 ..< 41),
            ExpectedArgumentInfo(line: 2, name: "secondArgument", nameRange: 44 ..< 58, value: "secondValue", valueRange: 62 ..< 73),
            parsing: """

            @DirectiveName( firstArgument:firstValue ,\tsecondArgument: \t secondValue)
            """
        )
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 2, name: "firstArgument", nameRange: 19 ..< 32, value: "firstValue", valueRange: 33 ..< 43),
            ExpectedArgumentInfo(line: 2, name: "secondArgument", nameRange: 46 ..< 60, value: "secondValue", valueRange: 64 ..< 75),
            parsing: """

              @DirectiveName( firstArgument:firstValue ,\tsecondArgument: \t secondValue)
            """
        )
        
        // Second argument on new line
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 1, name: "firstArgument", nameRange: 17 ..< 30, value: "firstValue", valueRange: 31 ..< 41),
            ExpectedArgumentInfo(line: 2, name: "secondArgument", nameRange: 16 ..< 30, value: "secondValue", valueRange: 34 ..< 45),
            parsing: """
            @DirectiveName( firstArgument:firstValue ,
                           secondArgument: \t secondValue)
            """
        )
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 2, name: "firstArgument", nameRange: 17 ..< 30, value: "firstValue", valueRange: 31 ..< 41),
            ExpectedArgumentInfo(line: 3, name: "secondArgument", nameRange: 16 ..< 30, value: "secondValue", valueRange: 34 ..< 45),
            parsing: """

            @DirectiveName( firstArgument:firstValue ,
                           secondArgument: \t secondValue)
            """
        )
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 2, name: "firstArgument", nameRange: 19 ..< 32, value: "firstValue", valueRange: 33 ..< 43),
            ExpectedArgumentInfo(line: 3, name: "secondArgument", nameRange: 18 ..< 32, value: "secondValue", valueRange: 36 ..< 47),
            parsing: """

              @DirectiveName( firstArgument:firstValue ,
                             secondArgument: \t secondValue)
            """
        )
        
        // Arguments on separate lines
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 2, name: "firstArgument", nameRange: 3 ..< 16, value: "firstValue", valueRange: 17 ..< 27),
            ExpectedArgumentInfo(line: 3, name: "secondArgument", nameRange: 2 ..< 16, value: "secondValue", valueRange: 20 ..< 31),
            parsing: """
            @DirectiveName(
              firstArgument:firstValue ,
            \tsecondArgument: \t secondValue
            )
            """
        )
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 3, name: "firstArgument", nameRange: 3 ..< 16, value: "firstValue", valueRange: 17 ..< 27),
            ExpectedArgumentInfo(line: 4, name: "secondArgument", nameRange: 2 ..< 16, value: "secondValue", valueRange: 20 ..< 31),
            parsing: """
            
            @DirectiveName(
              firstArgument:firstValue ,
            \tsecondArgument: \t secondValue
            )
            """
        )
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 3, name: "firstArgument", nameRange: 5 ..< 18, value: "firstValue", valueRange: 19 ..< 29),
            ExpectedArgumentInfo(line: 4, name: "secondArgument", nameRange: 4 ..< 18, value: "secondValue", valueRange: 22 ..< 33),
            parsing: """
            
              @DirectiveName(
                firstArgument:firstValue ,
              \tsecondArgument: \t secondValue
              )
            """
        )
        
        // Content and directives with emoji
        
        try assertDirectiveArguments(
            ExpectedArgumentInfo(line: 3, name: "firstArgument", nameRange: 20 ..< 33, value: "first💻Value", valueRange: 35 ..< 49),
            ExpectedArgumentInfo(line: 3, name: "secondArgument", nameRange: 51 ..< 65, value: "secondValue", valueRange: 67 ..< 78),
            parsing: """
            Paragraph before with emoji: 💻
            
            @Directive💻Name(firstArgument: first💻Value, secondArgument: secondValue)
            """
        )
    }

    // FIXME: swift-testing macro for specifying the relationship between a bug and a test
    // Uncomment the following code when we integrate swift-testing
    // @Test("Directive MultiLine WithoutContent Parsing", .bug("#152", relationship: .verifiesFix))
    func testDirectiveMultiLineWithoutContentParsing() throws {
        let source = """
        @Image(
          source: "example.png",
          alt: "Example image"
        )
        """

        let document = Document(parsing: source, options: .parseBlockDirectives)
        _ = try XCTUnwrap(document.child(at: 0) as? BlockDirective)
        let expected = #"""
        Document @1:1-4:2
        └─ BlockDirective @1:1-4:2 name: "Image"
           ├─ Argument text segments:
           |    @2:1-2:25: "  source: \"example.png\","
           |    @3:1-3:23: "  alt: \"Example image\""
        """#
        XCTAssertEqual(expected, document.debugDescription(options: .printSourceLocations))
    }
}
