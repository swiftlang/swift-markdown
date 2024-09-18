/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

class AsideTests: XCTestCase {
    func testTags() {
        for kind in Aside.Kind.allCases {
            let source = "> \(kind.rawValue): This is a `\(kind.rawValue)` aside."
            let document = Document(parsing: source)
            let blockQuote = document.child(at: 0) as! BlockQuote
            let aside = Aside(blockQuote)
            XCTAssertEqual(kind, aside.kind)

            // Note that the initial text in the paragraph has been adjusted
            // to after the tag.
            let expectedRootDump = """
                Document
                └─ BlockQuote
                   └─ Paragraph
                      ├─ Text "This is a "
                      ├─ InlineCode `\(kind.rawValue)`
                      └─ Text " aside."
                """
            XCTAssertEqual(expectedRootDump, aside.content[0].root.debugDescription())
        }
    }

    func testMissingTag() {
        let source = "> This is a regular block quote."
        let document = Document(parsing: source)
        let blockQuote = document.child(at: 0) as! BlockQuote
        let aside = Aside(blockQuote)
        XCTAssertEqual(.note, aside.kind)
        XCTAssertTrue(aside.content[0].root.isIdentical(to: document))
    }

    func testCustomTag() {
        let source = "> Hmm: This is something"
        let document = Document(parsing: source)
        let blockQuote = document.child(at: 0) as! BlockQuote
        let aside = Aside(blockQuote)
        XCTAssertEqual(.init(rawValue: "Hmm")!, aside.kind)
        
        // Note that the initial text in the paragraph has been adjusted
        // to after the tag.
        let expectedRootDump = """
            Document
            └─ BlockQuote
               └─ Paragraph
                  └─ Text "This is something"
            """
        XCTAssertEqual(expectedRootDump, aside.content[0].root.debugDescription())
    }

    func testNoParagraphAtStart() {
        let source = """
            > - A
            > - List?
            """
        let document = Document(parsing: source)
        let blockQuote = document.child(at: 0) as! BlockQuote
        let aside = Aside(blockQuote)
        XCTAssertEqual(.note, aside.kind)
        XCTAssertTrue(aside.content[0].root.isIdentical(to: document))
    }

    func testConversionStrategySingleWord() throws {
        do {
            let source = """
            > This is a regular block quote.
            """
            let document = Document(parsing: source)
            let blockQuote = document.child(at: 0) as! BlockQuote
            XCTAssertNil(Aside(blockQuote, tagRequirement: .requireSingleWordTag))
        }

        do {
            let source = "> See Also: A different topic."
            let document = Document(parsing: source)
            let blockQuote = document.child(at: 0) as! BlockQuote
            XCTAssertNil(Aside(blockQuote, tagRequirement: .requireSingleWordTag))
        }

        do {
            let source = "> Important: This is an aside."
            let expectedRootDump = """
            Document @/path/to/some-file.md:1:1-/path/to/some-file.md:1:31
            └─ BlockQuote @/path/to/some-file.md:1:1-/path/to/some-file.md:1:31
               └─ Paragraph @/path/to/some-file.md:1:3-/path/to/some-file.md:1:31
                  └─ Text @/path/to/some-file.md:1:14-/path/to/some-file.md:1:31 "This is an aside."
            """
            try assertAside(
                source: source,
                conversionStrategy: .requireSingleWordTag,
                expectedKind: .init(rawValue: "Important")!,
                expectedRootDump: expectedRootDump)
        }
    }

    func testConversionStrategyMultipleWords() throws {
        do {
            let source = """
            > This is a regular block quote.
            """
            let document = Document(parsing: source)
            let blockQuote = document.child(at: 0) as! BlockQuote
            XCTAssertNil(Aside(blockQuote, tagRequirement: .requireAnyLengthTag))
        }

        do {
            let source = "> See Also: A different topic."
            let expectedRootDump = """
            Document @/path/to/some-file.md:1:1-/path/to/some-file.md:1:31
            └─ BlockQuote @/path/to/some-file.md:1:1-/path/to/some-file.md:1:31
               └─ Paragraph @/path/to/some-file.md:1:3-/path/to/some-file.md:1:31
                  └─ Text @/path/to/some-file.md:1:13-/path/to/some-file.md:1:31 "A different topic."
            """
            try assertAside(
                source: source,
                conversionStrategy: .requireAnyLengthTag,
                expectedKind: .init(rawValue: "See Also")!,
                expectedRootDump: expectedRootDump)
        }

        do {
            let source = "> Important: This is an aside."
            let expectedRootDump = """
            Document @/path/to/some-file.md:1:1-/path/to/some-file.md:1:31
            └─ BlockQuote @/path/to/some-file.md:1:1-/path/to/some-file.md:1:31
               └─ Paragraph @/path/to/some-file.md:1:3-/path/to/some-file.md:1:31
                  └─ Text @/path/to/some-file.md:1:14-/path/to/some-file.md:1:31 "This is an aside."
            """
            try assertAside(
                source: source,
                conversionStrategy: .requireAnyLengthTag,
                expectedKind: .init(rawValue: "Important")!,
                expectedRootDump: expectedRootDump)
        }
    }

    func testConversionStrategyAllowNoLabel() throws {
        do {
            let source = """
            > This is a regular block quote.
            """
            let expectedRootDump = """
            Document @/path/to/some-file.md:1:1-/path/to/some-file.md:1:33
            └─ BlockQuote @/path/to/some-file.md:1:1-/path/to/some-file.md:1:33
               └─ Paragraph @/path/to/some-file.md:1:3-/path/to/some-file.md:1:33
                  └─ Text @/path/to/some-file.md:1:3-/path/to/some-file.md:1:33 "This is a regular block quote."
            """
            try assertAside(
                source: source,
                conversionStrategy: .tagNotRequired,
                expectedKind: .note,
                expectedRootDump: expectedRootDump)
        }

        do {
            let source = "> See Also: A different topic."
            let expectedRootDump = """
            Document @/path/to/some-file.md:1:1-/path/to/some-file.md:1:31
            └─ BlockQuote @/path/to/some-file.md:1:1-/path/to/some-file.md:1:31
               └─ Paragraph @/path/to/some-file.md:1:3-/path/to/some-file.md:1:31
                  └─ Text @/path/to/some-file.md:1:13-/path/to/some-file.md:1:31 "A different topic."
            """
            try assertAside(
                source: source,
                conversionStrategy: .tagNotRequired,
                expectedKind: .init(rawValue: "See Also")!,
                expectedRootDump: expectedRootDump)
        }

        do {
            let source = "> Important: This is an aside."
            let expectedRootDump = """
            Document @/path/to/some-file.md:1:1-/path/to/some-file.md:1:31
            └─ BlockQuote @/path/to/some-file.md:1:1-/path/to/some-file.md:1:31
               └─ Paragraph @/path/to/some-file.md:1:3-/path/to/some-file.md:1:31
                  └─ Text @/path/to/some-file.md:1:14-/path/to/some-file.md:1:31 "This is an aside."
            """
            try assertAside(
                source: source,
                conversionStrategy: .tagNotRequired,
                expectedKind: .init(rawValue: "Important")!,
                expectedRootDump: expectedRootDump)
        }
    }

    /// Ensure that creating block quotes by construction doesn't trip the "loss of source information" assertion
    /// by mistakenly gaining source information.
    func testConstructedBlockQuoteDoesntChangeRangeSource() throws {
        let source = "Note: This is just a paragraph."
        let fakeFileLocation = URL(fileURLWithPath: "/path/to/some-file.md")
        let document = Document(parsing: source, source: fakeFileLocation)
        let paragraph = try XCTUnwrap(document.child(at: 0) as? Paragraph)

        // this block quote has no source information, but its children do
        let blockQuote = BlockQuote(paragraph)
        let aside = try XCTUnwrap(Aside(blockQuote))

        let expectedRootDump = """
        BlockQuote
        └─ Paragraph @/path/to/some-file.md:1:1-/path/to/some-file.md:1:32
           └─ Text @/path/to/some-file.md:1:7-/path/to/some-file.md:1:32 "This is just a paragraph."
        """

        XCTAssertEqual(expectedRootDump, aside.content[0].root.debugDescription(options: .printSourceLocations))
    }

    func assertAside(source: String, conversionStrategy: Aside.TagRequirement, expectedKind: Aside.Kind, expectedRootDump: String, file: StaticString = #file, line: UInt = #line) throws {
        let fakeFileLocation = URL(fileURLWithPath: "/path/to/some-file.md")
        let document = Document(parsing: source, source: fakeFileLocation)
        let blockQuote = document.child(at: 0) as! BlockQuote
        let aside = try XCTUnwrap(Aside(blockQuote, tagRequirement: conversionStrategy))

        XCTAssertEqual(
            blockQuote.range?.lowerBound.source,
            aside.content.first?.range?.lowerBound.source,
            "The parsed aside should not lose source file information",
            file: file, line: line
        )

        XCTAssertEqual(expectedKind, aside.kind, file: file, line: line)
        XCTAssertEqual(
            expectedRootDump,
            aside.content[0].root.debugDescription(options: .printSourceLocations),
            file: file, line: line
        )
    }
}
