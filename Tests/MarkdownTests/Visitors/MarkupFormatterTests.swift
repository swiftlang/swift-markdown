/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import Markdown
import XCTest

/// Tests single-element printing capabilities
class MarkupFormatterSingleElementTests: XCTestCase {
    func testPrintBlockQuote() {
        let expected = "> A block quote."
        let printed = BlockQuote(Paragraph(Text("A block quote."))).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintCodeBlock() {
        let expected = """
        ```
        struct MyStruct {
            func foo() {}
        }
        ```
        """
        let code = """
        struct MyStruct {
            func foo() {}
        }
        """
        let printed = CodeBlock(code).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintHeadingATX() {
        for level in 1..<6 {
            let expected = String(repeating: "#", count: level) + " H\(level)"
            let printed = Heading(level: level, Text("H\(level)")).format()
            XCTAssertEqual(expected, printed)
        }
    }

    func testPrintHeadingSetext() {
        let options = MarkupFormatter.Options(preferredHeadingStyle: .setext)
        do { // H1
            let printed = Heading(level: 1, Text("Level-1 Heading"))
                .format(options: options) 
            let expected = """
            Level-1 Heading
            ===============
            """
            XCTAssertEqual(expected, printed)
        }

        do { // H2
            let printed = Heading(level: 2, Text("Level-2 Heading"))
                .format(options: options)
            let expected = """
            Level-2 Heading
            ---------------
            """
            XCTAssertEqual(expected, printed)
        }

        do { // H3 - there is no Setext H3 and above; fall back to ATX
            for level in 3...6 {
                let expected = String(repeating: "#", count: level) + " H\(level)"
                let printed = Heading(level: level, Text("H\(level)")).format()
                XCTAssertEqual(expected, printed)
            }
        }

        do { // Check last line length works with soft breaks
            let printed = Heading(level: 1,
                                  Text("First line"),
                                  SoftBreak(),
                                  Text("Second line"))
                .format(options: options)
            let expected = """
            First line
            Second line
            ===========
            """
            XCTAssertEqual(expected, printed)
        }
    }

    func testPrintThematicBreak() {
        XCTAssertEqual("-----", ThematicBreak().format())
    }

    func testPrintListItem() {
        do { // no checkbox
            // A list item printed on its own cannot determine its list marker
            // without its parent, so its contents are printed.
            let expected = "A list item."
            let printed = ListItem(Paragraph(Text("A list item."))).format()
            XCTAssertEqual(expected, printed)
        }
    }

    func testPrintUnorderedList() {
        do { // no checkbox
            let expected = "- A list item."
            let printed = UnorderedList(ListItem(Paragraph(Text("A list item.")))).format()
            XCTAssertEqual(expected, printed)
        }
        do { // unchecked
            let expected = "- [ ] A list item."
            let printed = UnorderedList(ListItem(checkbox: .unchecked,
                                                 Paragraph(Text("A list item.")))).format()
            XCTAssertEqual(expected, printed)
        }
        do { // unchecked
            let expected = "- [x] A list item."
            let printed = UnorderedList(ListItem(checkbox: .checked,
                                                 Paragraph(Text("A list item.")))).format()
            XCTAssertEqual(expected, printed)
        }

    }

    func testPrintOrderedList() {
        do { // no checkbox
            let expected = "1. A list item."
            let printed = OrderedList(ListItem(Paragraph(Text("A list item.")))).format()
            XCTAssertEqual(expected, printed)
        }
        do { // unchecked
            let expected = "1. [ ] A list item."
            let printed = OrderedList(ListItem(checkbox: .unchecked,
                                               Paragraph(Text("A list item.")))).format()
            XCTAssertEqual(expected, printed)
        }
        do { // checked
            let expected = "1. [x] A list item."
            let printed = OrderedList(ListItem(checkbox: .checked,
                                               Paragraph(Text("A list item.")))).format()
            XCTAssertEqual(expected, printed)
        }
    }

    func testPrintOrderedListCustomStart() {
        let options = MarkupFormatter.Options(orderedListNumerals: .allSame(2))
        do { // no checkbox
            let expected = "2. A list item."
            var renderedList = OrderedList(ListItem(Paragraph(Text("A list item."))))
            renderedList.startIndex = 2
            let printed = renderedList.format(options: options)
            XCTAssertEqual(expected, printed)
        }
        do { // unchecked
            let expected = "2. [ ] A list item."
            var renderedList = OrderedList(ListItem(checkbox: .unchecked,
                                                    Paragraph(Text("A list item."))))
            renderedList.startIndex = 2
            let printed = renderedList.format(options: options)
            XCTAssertEqual(expected, printed)
        }
        do { // checked
            let expected = "2. [x] A list item."
            var renderedList = OrderedList(ListItem(checkbox: .checked,
                                                    Paragraph(Text("A list item."))))
            renderedList.startIndex = 2
            let printed = renderedList.format(options: options)
            XCTAssertEqual(expected, printed)
        }
    }

    func testPrintParagraph() {
        let expected = "A paragraph."
        let printed = Paragraph(Text("A paragraph.")).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintTwoParagraphs() {
        let expected = """
        First paragraph.

        Second paragraph.
        """
        let printed = Document(
            Paragraph(Text("First paragraph.")),
            Paragraph(Text("Second paragraph."))
        ).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintInlineCode() {
        let expected = "`foo`"
        let printed = InlineCode("foo").format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintEmphasis() {
        let expected = "*emphasized*"
        let printed = Emphasis(Text("emphasized")).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintStrong() {
        let expected = "**strong**"
        let printed = Strong(Text("strong")).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintEmphasisInStrong() {
        let expected = "***strong***"
        let printed = Strong(Emphasis(Text("strong"))).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintInlineHTML() {
        let expected = "<b>"
        let printed = InlineHTML("<b>").format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintLineBreak() {
        let expected = "Line  \nbreak."
        let printed = Paragraph(Text("Line"), LineBreak(), Text("break.")).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintLink() {
        let linkText = "Link text"
        let destination = "https://swift.org"
        let expected = "[\(linkText)](\(destination))"
        let printed = Link(destination: destination, Text(linkText)).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintLinkCondenseAutolink() {
        let linkText = "https://swift.org"
        let destination = linkText
        let expected = "<\(destination)>"
        let printed = Link(destination: destination, Text(linkText)).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintImage() {
        let source = "test.png"
        let altText = "Alt text"
        let title = "title"
        do { // Everything present
            let expected = "![\(altText)](\(source) \"\(title)\")"
            let printed = Image(source: source, title: title, Text(altText)).format()
            XCTAssertEqual(expected, printed)
        }

        do { // Missing title
            let expected = "![\(altText)](\(source))"
            let printed = Image(source: source, Text(altText)).format()
            XCTAssertEqual(expected, printed)
        }

        do { // Missing text
            let expected = "![](\(source))"
            let printed = Image(source: source).format()
            XCTAssertEqual(expected, printed)
        }

        do { // Missing everything
            let expected = "![]()" // Yes, this is valid.
            let printed = Image().format()
            XCTAssertEqual(expected, printed)
        }
    }

    func testPrintSoftBreak() {
        let expected = "Soft\nbreak."
        let printed = Paragraph(Text("Soft"), SoftBreak(), Text("break.")).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintText() {
        let expected = "Some text."
        let printed = Text("Some text.").format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintSymbolLink() {
        let expected = "``foo()``"
        let printed = SymbolLink(destination: "foo()").format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintDoxygenPrefix() {
        let expectedSlash = #"\discussion Discussion"#
        let printedSlash = DoxygenDiscussion(children: Paragraph(Text("Discussion")))
            .format(options: .init(doxygenCommandPrefix: .backslash))
        XCTAssertEqual(expectedSlash, printedSlash)

        let expectedAt = "@discussion Discussion"
        let printedAt = DoxygenDiscussion(children: Paragraph(Text("Discussion")))
            .format(options: .init(doxygenCommandPrefix: .at))
        XCTAssertEqual(expectedAt, printedAt)
    }

    func testPrintDoxygenAbstract() {
            let expected = #"\abstract Another thing."#
            let printed = DoxygenAbstract(children: Paragraph(Text("Another thing."))).format()
            print (printed)
            XCTAssertEqual(expected, printed)
    }

    func testPrintDoxygenAbstractMultiline() {
        let expected = #"""
        \abstract Another thing.
        This is an extended abstract.
        """#
        let printed = DoxygenAbstract(children: Paragraph(
            Text("Another thing."),
            SoftBreak(),
            Text("This is an extended abstract.")
        )).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintDoxygenDiscussion() {
        let expected = #"\discussion Another thing."#
        let printed = DoxygenDiscussion(children: Paragraph(Text("Another thing."))).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintDoxygenDiscussionMultiline() {
        let expected = #"""
        \discussion Another thing.
        This is an extended discussion.
        """#
        let printed = DoxygenDiscussion(children: Paragraph(
            Text("Another thing."),
            SoftBreak(),
            Text("This is an extended discussion.")
        )).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintDoxygenNote() {
        let expected = #"\note Another thing."#
        let printed = DoxygenNote(children: Paragraph(Text("Another thing."))).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintDoxygenNoteMultiline() {
        let expected = #"""
        \note Another thing.
        This is an extended discussion.
        """#
        let printed = DoxygenNote(children: Paragraph(
            Text("Another thing."),
            SoftBreak(),
            Text("This is an extended discussion.")
        )).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintDoxygenParameter() {
        let expected = #"\param thing The thing."#
        let printed = DoxygenParameter(name: "thing", children: Paragraph(Text("The thing."))).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintDoxygenParameterMultiline() {
        let expected = #"""
        \param thing The thing.
        This is an extended discussion.
        """#
        let printed = DoxygenParameter(name: "thing", children: Paragraph(
            Text("The thing."),
            SoftBreak(),
            Text("This is an extended discussion.")
        )).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintDoxygenReturns() {
        let expected = #"\returns Another thing."#
        let printed = DoxygenReturns(children: Paragraph(Text("Another thing."))).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintDoxygenReturnsMultiline() {
        let expected = #"""
        \returns Another thing.
        This is an extended discussion.
        """#
        let printed = DoxygenReturns(children: Paragraph(
            Text("Another thing."),
            SoftBreak(),
            Text("This is an extended discussion.")
        )).format()
        XCTAssertEqual(expected, printed)
    }

    func testPrintBlockDirective() {
        let expected = #"""
        @Metadata {
            @TitleHeading(Example)
        }
        """#
        let printed = BlockDirective(name: "Metadata", children: [
            BlockDirective(name: "TitleHeading", argumentText: "Example"),
        ]).format()
        XCTAssertEqual(expected, printed)
    }
}

/// Tests that formatting options work correctly.
class MarkupFormatterOptionsTests: XCTestCase {
    func testUnorderedListMarker() {
        let original = Document(parsing: "- A")
        do {
            let printed = original.format(options: .init(unorderedListMarker: .plus))
            XCTAssertEqual("+ A", printed)
        }

        do {
            let printed = original.format(options: .init(unorderedListMarker: .star))
            XCTAssertEqual("* A", printed)
        }
    }

    func testUseCodeFence() {
        let fenced = """
        ```swift
        func foo() {}
        ```

        -----

        ```
        func foo() {}
        ```
        """

        let refenced = """
        ```
        func foo() {}
        ```

        -----

        ```
        func foo() {}
        ```
        """

        let unfenced = """
            func foo() {}

        -----

            func foo() {}
        """

        do { // always
            let document = Document(parsing: unfenced)
            let printed = document.format(options: .init(useCodeFence: .always))
            XCTAssertEqual(refenced, printed)
        }

        do { // never
            let document = Document(parsing: fenced)
            let printed = document.format(options: .init(useCodeFence: .never))
            XCTAssertEqual(unfenced, printed)
        }

        do { // when language present
            let document = Document(parsing: fenced)
            let expected = """
            ```swift
            func foo() {}
            ```

            -----

                func foo() {}
            """
            let printed = document.format(options: .init(useCodeFence: .onlyWhenLanguageIsPresent))
            XCTAssertEqual(expected, printed)
        }
    }

    func testDefaultCodeBlockLanguage() {
        let unfenced = """
            func foo() {}
        """
        let fencedWithLanguage = """
        ```swift
        func foo() {}
        ```
        """
        let fencedWithoutLanguage = """
        ```
        func foo() {}
        ```
        """
        do { // nil
            let document = Document(parsing: unfenced)
            let printed = document.format()
            XCTAssertEqual(fencedWithoutLanguage, printed)
        }

        do { // swift
            let document = Document(parsing: unfenced)
            let printed = document.format(options: .init(defaultCodeBlockLanguage: "swift"))
            XCTAssertEqual(fencedWithLanguage, printed)
        }
    }

    func testThematicBreakCharacter() {
        let thematicBreakLength: UInt = 5
        for character in MarkupFormatter.Options.ThematicBreakCharacter.allCases {
            let options = MarkupFormatter.Options(thematicBreakCharacter: character, thematicBreakLength: thematicBreakLength)
            let expected = String(repeating: character.rawValue, count: Int(thematicBreakLength))
            let printed = ThematicBreak().format(options: options)
            XCTAssertEqual(expected, printed)
        }
    }

    func testThematicBreakLength() {
        let expected = "---"
        let printed = ThematicBreak().format(options: .init(thematicBreakLength: 3))
        XCTAssertEqual(expected, printed)
    }

    func testEmphasisMarker() {
        do { // Emphasis
            let underline = "_emphasized_"
            let star = "*emphasized*"

            do {
                let document = Document(parsing: underline)
                let printed = document.format(options: .init(emphasisMarker: .star))
                XCTAssertEqual(star, printed)
            }

            do {
                let document = Document(parsing: star)
                let printed = document.format(options: .init(emphasisMarker: .underline))
                XCTAssertEqual(underline, printed)
            }
        }

        do { // Strong
            let underline = "__strong__"
            let star = "**strong**"

            do {
                let document = Document(parsing: underline)
                let printed = document.format(options: .init(emphasisMarker: .star))
                XCTAssertEqual(star, printed)
            }

            do {
                let document = Document(parsing: star)
                let printed = document.format(options: .init(emphasisMarker: .underline))
                XCTAssertEqual(underline, printed)
            }

        }
    }

    func testOrderedListNumeralsAllSame() {
        let incrementing = """
        1. A
        2. B
        3. C
        """
        let allSame = """
        1. A
        1. B
        1. C
        """
        do {
            let document = Document(parsing: incrementing)
            let printed = document.format(options: .init(orderedListNumerals: .allSame(1)))
            XCTAssertEqual(allSame, printed)
        }

        do {
            let document = Document(parsing: allSame)
            let printed = document.format(options: .init(orderedListNumerals: .incrementing(start: 1)))
            XCTAssertEqual(incrementing, printed)
        }
    }

    func testDoxygenCommandPrefix() {
        let backslash = #"\param thing The thing."#
        let at = "@param thing The thing."

        do {
            let document = Document(parsing: backslash, options: [.parseMinimalDoxygen, .parseBlockDirectives])
            let printed = document.format(options: .init(doxygenCommandPrefix: .at))
            XCTAssertEqual(at, printed)
        }

        do {
            let document = Document(parsing: at, options: [.parseMinimalDoxygen, .parseBlockDirectives])
            let printed = document.format(options: .init(doxygenCommandPrefix: .backslash))
            XCTAssertEqual(backslash, printed)
        }
    }
}

/// Tests that an printed and reparsed element has the same structure as
/// the original.
class MarkupFormatterSimpleRoundTripTests: XCTestCase {
    func checkRoundTrip(for element: Markup,
                        file: StaticString = #file,
                        line: UInt = #line) {
        let printed = element.format()
        let parsed = Document(parsing: printed)
        XCTAssertTrue(element.hasSameStructure(as: parsed), file: file, line: line)
    }

    func checkRoundTrip(for source: String,
                        file: StaticString = #file,
                        line: UInt = #line) {
        checkRoundTrip(for: Document(parsing: source), file: file, line: line)
    }

    func checkCharacterEquivalence(for source: String,
                                   file: StaticString = #file,
                                   line: UInt = #line) {
        let original = Document(parsing: source)
        let printed = original.format()
        XCTAssertEqual(source, printed, file: file, line: line)
    }

    func testRoundTripInlines() {
        checkRoundTrip(for: Document(Paragraph(InlineCode("foo"))))
        checkRoundTrip(for: Document(Paragraph(Emphasis(Text("emphasized")))))
        checkRoundTrip(for: Document(Paragraph(Image(source: "test.png", title: "test", [Text("alt")]))))
        checkRoundTrip(for: Document(Paragraph(Text("OK."), InlineHTML("<b>"))))
        checkRoundTrip(for: Document(Paragraph(
            Text("First line"),
            LineBreak(),
            Text("Second line"))))
        checkRoundTrip(for: Document(Paragraph(Link(destination: "https://swift.org", Text("Swift")))))
        checkRoundTrip(for: Document(Paragraph(
            Text("First line"),
            SoftBreak(),
            Text("Second line"))))
        checkRoundTrip(for: Document(Paragraph(Strong(Text("strong")))))
        checkRoundTrip(for: Document(Paragraph(Text("OK"))))
        checkRoundTrip(for: Document(Paragraph(Emphasis(Strong(Text("emphasized and strong"))))))
        checkRoundTrip(for: Document(Paragraph(InlineCode("foo"))))
        // According to cmark, ***...*** is always Emphasis(Strong(...)).
    }

    func testRoundTripBlockQuote() {
        let source = """
            > A
            > block
            > quote.
            """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripBlockQuoteInBlockQuote() {
        let source = """
            > A block quote
            > > Within a block quote!
            >
            > Resuming outer block quote.
            """
        checkRoundTrip(for: source)
    }

    func testRoundTripFencedCodeBlockInBlockQuote() {
        let source = """
            > ```swift
            > struct MyStruct {
            >     func foo() {}
            > }
            > ```
            """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripUnorderedListSingleFlat() {
        let source = "- A"
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripUnorderedListDoubleFlat() {
        let source = """
            - A
            - B
            """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripUnorderedListInUnorderedList() {
        let source = """
            - A
              - B
              - C
            - D
            """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripUnorderedListExtremeNest() {
        let source = """
            - A
              - B
                - C
                  - D
            """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripOrderedListSingleFlat() {
        let source = "1. A"
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripOrderedListDoubleFlat() {
        let source = """
            1. A
            1. B
            """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripOrderedListInUnorderedList() {
        let source = """
            1. A
               1. B
               1. C
            1. D
            """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripOrderedListExtremeNest() {
        let source = """
            1. A
               1. B
                  1. C
                     1. D
            """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripFencedCodeBlock() {
        let source = """
            ```swift
            struct MyStruct {
                func foo() {}
            }
            ```
            """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripHardBreakWithInlineCode() {
        let source = """
        This is some text.\("  ")
        `This is some code.`
        """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripSoftBreakWithInlineCode() {
        let source = """
        This is some text.
        `This is some code.`
        """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripHardBreakWithImage() {
        let source = """
        This is some text.\("  ")
        ![This is an image.](image.png)
        """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripSoftBreakWithImage() {
        let source = """
        This is some text.
        ![This is an image.](image.png)
        """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripHardBreakWithLink() {
        let source = """
        This is some text.\("  ")
        [This is a link.](https://swift.org)
        """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripSoftBreakWithLink() {
        let source = """
        This is some text.
        [This is a link.](https://swift.org)
        """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripHardBreakWithInlineAttribute() {
        let source = """
        This is some text.\("  ")
        ^[This is some attributed text.](rainbow: 'extreme')
        """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    func testRoundTripSoftBreakWithInlineAttribute() {
        let source = """
        This is some text.
        ^[This is some attributed text.](rainbow: 'extreme')
        """
        checkRoundTrip(for: source)
        checkCharacterEquivalence(for: source)
    }

    /// Why not?
    func testRoundTripReadMe() throws {
        let readMeURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // (Remove this file)
            .deletingLastPathComponent() // ../  (Visitors)
            .deletingLastPathComponent() // ../ (MarkdownTests)
            .deletingLastPathComponent() // ../ (Tests)
            .appendingPathComponent("README.md") // README.md
        let document = try Document(parsing: readMeURL)
//        try document.format().write(toFile: "/tmp/test.md", atomically: true, encoding: .utf8)
        checkRoundTrip(for: document)
    }
}

/**
 Test enforcement of a preferred maximum line length.

 In general, the formatter should never make changes that would cause the
 formatted result to have a different syntax tree structure than the original.

 However, when splitting lines, it has to insert soft/hard breaks into
 ``Text`` elements.

 However, it still should never change the structure of
 ``BlockMarkup`` elements with line splitting enabled.

 It should also never turn any inline element containing ``Text`` elements
 into something else. For example, a link with really long link text shouldn't
 be doubly split, turning the image into two paragraphs.
 */
class MarkupFormatterLineSplittingTests: XCTestCase {
    typealias PreferredLineLimit = MarkupFormatter.Options.PreferredLineLimit

    /**
     Test the basic soft break case in a paragraph.
     */
    func testBasicSoftBreaks() {
        let lineLength = 20
        let source = "A really really really really really really really really really really really really long line"
        let options = MarkupFormatter.Options(preferredLineLimit: PreferredLineLimit(maxLength: lineLength, breakWith: .softBreak))
        let document = Document(parsing: source)
        let printed = document.format(options: options)
        let expected = """
        A really really
        really really
        really really
        really really
        really really
        really really long
        line
        """
        XCTAssertEqual(expected, printed)
        let expectedTreeDump = """
        Document
        └─ Paragraph
           ├─ Text "A really really"
           ├─ SoftBreak
           ├─ Text "really really"
           ├─ SoftBreak
           ├─ Text "really really"
           ├─ SoftBreak
           ├─ Text "really really"
           ├─ SoftBreak
           ├─ Text "really really"
           ├─ SoftBreak
           ├─ Text "really really long"
           ├─ SoftBreak
           └─ Text "line"
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())

        // In this particular case, since this is just a paragraph,
        // we can guarantee the maximum line length.
        for line in printed.split(separator: "\n") {
            XCTAssertLessThanOrEqual(line.count, lineLength)
        }
    }

    /**
     Test the basic hard line break case in a paragraph.
     */
    func testBasicHardBreaks() {
        let lineLength = 20
        let source = "A really really really really really really really really really really really really long line"
        let options = MarkupFormatter.Options(preferredLineLimit: PreferredLineLimit(maxLength: lineLength, breakWith: .hardBreak))
        let document = Document(parsing: source)
        let printed = document.format(options: options)
        let expected = """
        A really really\u{0020}\u{0020}
        really really\u{0020}\u{0020}
        really really\u{0020}\u{0020}
        really really\u{0020}\u{0020}
        really really\u{0020}\u{0020}
        really really\u{0020}\u{0020}
        long line
        """
        XCTAssertEqual(expected, printed)
        let expectedTreeDump = """
        Document
        └─ Paragraph
           ├─ Text "A really really"
           ├─ LineBreak
           ├─ Text "really really"
           ├─ LineBreak
           ├─ Text "really really"
           ├─ LineBreak
           ├─ Text "really really"
           ├─ LineBreak
           ├─ Text "really really"
           ├─ LineBreak
           ├─ Text "really really"
           ├─ LineBreak
           └─ Text "long line"
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())

        // In this particular case, since this is just a paragraph,
        // we can guarantee the maximum line length.
        for line in printed.split(separator: "\n") {
            XCTAssertLessThanOrEqual(line.count, lineLength)
        }
    }

    /**
     Test that line breaks maintain block structure in a flat, unordered list.
     */
    func testInUnorderedListItemSingle() {
        let source = """
        - Really really really really really really really really long list item
        """
        let document = Document(parsing: source)
        let printed = document.format(options: .init(preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = """
        - Really really
          really really
          really really
          really really
          long list item
        """
        XCTAssertEqual(expected, printed)

        let expectedTreeDump = """
        Document
        └─ UnorderedList
           └─ ListItem
              └─ Paragraph
                 ├─ Text "Really really"
                 ├─ SoftBreak
                 ├─ Text "really really"
                 ├─ SoftBreak
                 ├─ Text "really really"
                 ├─ SoftBreak
                 ├─ Text "really really"
                 ├─ SoftBreak
                 └─ Text "long list item"
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())
    }

    /**
     Test that line breaks maintain block structure in a nested, unordered list.
     */
    func testInUnorderedListItemNested() {
        let source = """
        - First level
          - Second level is really really really really really long.
        - First level again.
        """
        let document = Document(parsing: source)
        let printed = document.format(options: .init(preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = """
        - First level
          - Second level is
            really really
            really really
            really long.
        - First level
          again.
        """
        XCTAssertEqual(expected, printed)

        let expectedTreeDump = """
        Document
        └─ UnorderedList
           ├─ ListItem
           │  ├─ Paragraph
           │  │  └─ Text "First level"
           │  └─ UnorderedList
           │     └─ ListItem
           │        └─ Paragraph
           │           ├─ Text "Second level is"
           │           ├─ SoftBreak
           │           ├─ Text "really really"
           │           ├─ SoftBreak
           │           ├─ Text "really really"
           │           ├─ SoftBreak
           │           └─ Text "really long."
           └─ ListItem
              └─ Paragraph
                 ├─ Text "First level"
                 ├─ SoftBreak
                 └─ Text "again."
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())
    }

    /**
     Test that line breaks maintain block structure in a flat, ordered list.
     */
    func testInOrderedListItemSingle() {
        let source = """
        1. Really really really really really really really really long list item
        """
        let document = Document(parsing: source)
        let printed = document.format(options: .init(preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = """
        1. Really really
           really really
           really really
           really really
           long list item
        """
        XCTAssertEqual(expected, printed)

        let expectedTreeDump = """
        Document
        └─ OrderedList
           └─ ListItem
              └─ Paragraph
                 ├─ Text "Really really"
                 ├─ SoftBreak
                 ├─ Text "really really"
                 ├─ SoftBreak
                 ├─ Text "really really"
                 ├─ SoftBreak
                 ├─ Text "really really"
                 ├─ SoftBreak
                 └─ Text "long list item"
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())
    }

    /**
     Test that line breaks maintain block structure in a nested list.
     */
    func testInOrderedListItemNested() {
        let source = """
        1. First level
           1. Second level is really really really really really long.
        1. First level again.
        """
        let document = Document(parsing: source)
        let printed = document.format(options: .init(preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = """
        1. First level
           1. Second level
              is really
              really really
              really really
              long.
        1. First level
           again.
        """
        XCTAssertEqual(expected, printed)

        let expectedTreeDump = """
        Document
        └─ OrderedList
           ├─ ListItem
           │  ├─ Paragraph
           │  │  └─ Text "First level"
           │  └─ OrderedList
           │     └─ ListItem
           │        └─ Paragraph
           │           ├─ Text "Second level"
           │           ├─ SoftBreak
           │           ├─ Text "is really"
           │           ├─ SoftBreak
           │           ├─ Text "really really"
           │           ├─ SoftBreak
           │           ├─ Text "really really"
           │           ├─ SoftBreak
           │           └─ Text "long."
           └─ ListItem
              └─ Paragraph
                 ├─ Text "First level"
                 ├─ SoftBreak
                 └─ Text "again."
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())
    }

    func testInOrderedListHugeNumerals() {
        let source = """
        1. Really really really really long line with huge numeral
        """
        let document = Document(parsing: source)
        let printed = document.format(options: .init(orderedListNumerals: .allSame(1000),
                                                     preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = """
        1000. Really really
              really really
              long line
              with huge
              numeral
        """
        XCTAssertEqual(expected, printed)

        let expectedTreeDump = """
        Document
        └─ OrderedList startIndex: 1000
           └─ ListItem
              └─ Paragraph
                 ├─ Text "Really really"
                 ├─ SoftBreak
                 ├─ Text "really really"
                 ├─ SoftBreak
                 ├─ Text "long line"
                 ├─ SoftBreak
                 ├─ Text "with huge"
                 ├─ SoftBreak
                 └─ Text "numeral"
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())
    }

    /**
     Test that line breaks maintain block structure in a block quote.
     */
    func testInBlockQuoteSingle() {
        let source = """
        > Really really really really really long line in a block quote.
        """
        let document = Document(parsing: source)
        let printed = document.format(options: .init(preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = """
        > Really really
        > really really
        > really long line
        > in a block quote.
        """
        XCTAssertEqual(expected, printed)

        let expectedTreeDump = """
        Document
        └─ BlockQuote
           └─ Paragraph
              ├─ Text "Really really"
              ├─ SoftBreak
              ├─ Text "really really"
              ├─ SoftBreak
              ├─ Text "really long line"
              ├─ SoftBreak
              └─ Text "in a block quote."
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())
    }

    /**
     Test that line breaks maintain block structure in a nested block quote.
     */
    func testInBlockQuoteNested() {
        let source = """
        > Really really really long line
        > > Whoa, really really really really long nested block quote
        >
        > Continuing outer quote.
        """
        let document = Document(parsing: source)
        let printed = document.format(options: .init(preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = """
        > Really really
        > really long line
        > >\u{0020}
        > > Whoa, really
        > > really really
        > > really long
        > > nested block
        > > quote
        >\u{0020}
        > Continuing outer
        > quote.
        """
        XCTAssertEqual(expected, printed)

        let expectedTreeDump = """
        Document
        └─ BlockQuote
           ├─ Paragraph
           │  ├─ Text "Really really"
           │  ├─ SoftBreak
           │  └─ Text "really long line"
           ├─ BlockQuote
           │  └─ Paragraph
           │     ├─ Text "Whoa, really"
           │     ├─ SoftBreak
           │     ├─ Text "really really"
           │     ├─ SoftBreak
           │     ├─ Text "really long"
           │     ├─ SoftBreak
           │     ├─ Text "nested block"
           │     ├─ SoftBreak
           │     └─ Text "quote"
           └─ Paragraph
              ├─ Text "Continuing outer"
              ├─ SoftBreak
              └─ Text "quote."
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())
    }

    /**
     Test that links are not destroyed when breaking long link text.
     */
    func testLongLinkText() {
        let source = """
        [Link with really really really long link text](https://swift.org)
        """
        let document = Document(parsing: source)
        let printed = document.format(options: .init(preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = """
        [Link with really
        really really long
        link text](https://swift.org)
        """
        // Note: Link destinations cannot be split.
        XCTAssertEqual(expected, printed)

        let expectedTreeDump = """
        Document
        └─ Paragraph
           └─ Link destination: "https://swift.org"
              ├─ Text "Link with really"
              ├─ SoftBreak
              ├─ Text "really really long"
              ├─ SoftBreak
              └─ Text "link text"
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())
    }

    /**
     Test that emphasis elements are not destroyed when breaking long inner text.
     */
    func testLongEmphasizedText() {
        let source = """
        *Really really really really long emphasized text*
        """
        let document = Document(parsing: source)
        let printed = document.format(options: .init(preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = """
        *Really really
        really really long
        emphasized text*
        """
        XCTAssertEqual(expected, printed)

        let expectedTreeDump = """
        Document
        └─ Paragraph
           └─ Emphasis
              ├─ Text "Really really"
              ├─ SoftBreak
              ├─ Text "really really long"
              ├─ SoftBreak
              └─ Text "emphasized text"
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())
    }

    /**
     Test that Emphasis(Strong(...)) are not destroyed when breaking long inner text.
     */
    func testLongEmphasizedStrongText() {
        let source = """
        **Really really really really long strongly emphasized text**
        """
        let document = Document(parsing: source)
        let printed = document.format(options: .init(preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = """
        **Really really
        really really long
        strongly emphasized
        text**
        """
        XCTAssertEqual(expected, printed)

        let expectedTreeDump = """
        Document
        └─ Paragraph
           └─ Strong
              ├─ Text "Really really"
              ├─ SoftBreak
              ├─ Text "really really long"
              ├─ SoftBreak
              ├─ Text "strongly emphasized"
              ├─ SoftBreak
              └─ Text "text"
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())
    }

    func testDontBreakHeadings() {
        let source = "### Really really really really really long heading"
        let document = Document(parsing: source)
        let printed = document.format(options: .init(preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = source
        XCTAssertEqual(expected, printed)

        let expectedTreeDump = """
        Document
        └─ Heading level: 3
           └─ Text "Really really really really really long heading"
        """
        XCTAssertEqual(expectedTreeDump, Document(parsing: printed).debugDescription())
    }

    func testInlineCode() {
        let source = "`sdf sdf sdf sdf sdf sdf sdf sdf`"
        let document = Document(parsing: source)
        let printed = document.format(options: .init(preferredLineLimit: .init(maxLength: 20, breakWith: .softBreak)))
        let expected = """
        `sdf sdf sdf sdf
        sdf sdf sdf sdf`
        """
        XCTAssertEqual(expected, printed)
        XCTAssertTrue(document.hasSameStructure(as: Document(parsing: printed)))
    }
}

class MarkupFormatterTableTests: XCTestCase {
    /// Test growing cell widths.
    func testGrowCellWidths() {
        let source = """
        |1|1|
        |--|--|
        |333|333|
        """

        let expected = """
        |1  |1  |
        |---|---|
        |333|333|
        """

        let document = Document(parsing: source)
        let formatted = document.format()
        XCTAssertEqual(expected, formatted)
    }

    /// Test that tables nested in other block elements still get printed
    /// correctly.
    func testNested() {
        do { // Inside blockquotes; unlikely but possible
            let source = """
            > |1|1|
            > |--|--|
            > |*333*|*333*|
            """

            let expected = """
            > |1    |1    |
            > |-----|-----|
            > |*333*|*333*|
            """

            let document = Document(parsing: source)
            let formatted = document.format()
            XCTAssertEqual(expected, formatted)
        }

        do { // Inside a list item; unlikely but possible
            let source = """
            - |1|1|
              |--|--|
              |333|333|
            """

            let expected = """
            - |1  |1  |
              |---|---|
              |333|333|
            """

            let document = Document(parsing: source)
            let formatted = document.format()
            XCTAssertEqual(expected, formatted)
        }
    }

    /// Test that an already uniformly sized table prints pretty much the same.
    func testNoGrowth() {
        let source = """
        > |1  |1  |
        > |---|---|
        > |333|333|
        """

        let expected = """
        > |1  |1  |
        > |---|---|
        > |333|333|
        """

        let document = Document(parsing: source)
        let formatted = document.format()
        XCTAssertEqual(expected, formatted)
    }

    func testNoSoftbreaksPrinted() {
        let head = Table.Head(Table.Cell(Text("Not"),
                                           SoftBreak(),
                                           Text("Broken")))
        let document = Document(Table(header: head, body: Table.Body()))

        let expected = """
        |Not Broken|
        |----------|
        """
        let formatted = document.format()
        XCTAssertEqual(expected, formatted)
    }

    func testRoundTripStructure() {
        let source = """
        |*A*|**B**|~C~|
        |:-|:--:|--:|
        |[Apple](https://apple.com)|![image](image.png)|<https://swift.org>|
        |<br/>|| |
        """

        let document = Document(parsing: source)
        let expectedDump = """
        Document
        └─ Table alignments: |l|c|r|
           ├─ Head
           │  ├─ Cell
           │  │  └─ Emphasis
           │  │     └─ Text "A"
           │  ├─ Cell
           │  │  └─ Strong
           │  │     └─ Text "B"
           │  └─ Cell
           │     └─ Strikethrough
           │        └─ Text "C"
           └─ Body
              ├─ Row
              │  ├─ Cell
              │  │  └─ Link destination: "https://apple.com"
              │  │     └─ Text "Apple"
              │  ├─ Cell
              │  │  └─ Image source: "image.png"
              │  │     └─ Text "image"
              │  └─ Cell
              │     └─ Link destination: "https://swift.org"
              │        └─ Text "https://swift.org"
              └─ Row
                 ├─ Cell colspan: 2
                 │  └─ InlineHTML <br/>
                 ├─ Cell colspan: 0
                 └─ Cell
        """
        XCTAssertEqual(expectedDump, document.debugDescription())

        let formatted = document.format()
        let expected = """
        |*A*                       |**B**              |~C~                |
        |:-------------------------|:-----------------:|------------------:|
        |[Apple](https://apple.com)|![image](image.png)|<https://swift.org>|
        |<br/>                                        ||                   |
        """
        XCTAssertEqual(expected, formatted)

        let reparsed = Document(parsing: formatted)
        XCTAssertTrue(document.hasSameStructure(as: reparsed))
    }

    func testRoundTripRowspan() {
        let source = """
        | one | two | three |
        | --- | --- | ----- |
        | big      || small |
        | ^        || small |
        """

        let document = Document(parsing: source)

        let expectedDump = """
        Document
        └─ Table alignments: |-|-|-|
           ├─ Head
           │  ├─ Cell
           │  │  └─ Text "one"
           │  ├─ Cell
           │  │  └─ Text "two"
           │  └─ Cell
           │     └─ Text "three"
           └─ Body
              ├─ Row
              │  ├─ Cell colspan: 2 rowspan: 2
              │  │  └─ Text "big"
              │  ├─ Cell colspan: 0
              │  └─ Cell
              │     └─ Text "small"
              └─ Row
                 ├─ Cell colspan: 2 rowspan: 0
                 ├─ Cell colspan: 0
                 └─ Cell
                    └─ Text "small"
        """
        XCTAssertEqual(expectedDump, document.debugDescription())

        let formatted = document.format()
        let expected = """
        |one|two|three|
        |---|---|-----|
        |big   ||small|
        |^     ||small|
        """

        XCTAssertEqual(expected, formatted)

        let reparsed = Document(parsing: formatted)
        XCTAssertTrue(document.hasSameStructure(as: reparsed))
    }
    
    func testColSpanOverflowTooManyIndicators() {
        let source = """
        | Jenis Kelamin | Jenis Tas     | Tally       | Jumlah |
        |---------------|---------------|-------------|--------|
        | Perempuan     | Tas Ransel    | ||||
        """
        let document = Document(parsing: source)
        let formatted = document.format()
        let expected = """
        |Jenis Kelamin|Jenis Tas |Tally|Jumlah|
        |-------------|----------|-----|------|
        |Perempuan    |Tas Ransel|           ||
        """
        XCTAssertEqual(expected, formatted)
    }
    
    func testColSpanOverflowMisformatted() {
        let source = """
        |A|B|C|
        |-|-|-|
        |1|2|3||4|5|6|
        """
        let document = Document(parsing: source)
        let formatted = document.format()
        let expected = """
        |A|B|C|
        |-|-|-|
        |1|2|3|
        """
        XCTAssertEqual(expected, formatted)
    }
    
    func testColSpanOverflowInHeader() {
        // Doesn't get parsed as a table, so doesn't exhibit the crash
        let source = """
        |A|B|C||-|-|-|
        |1|2|3|
        """
        let document = Document(parsing: source)
        let formatted = document.format()
        XCTAssertEqual(source, formatted)
    }
    
    func testColSpanOverflowInSubHeader() {
        // Doesn't get parsed as a table, so doesn't exhibit the crash
        let source = """
        |A|B|C|
        |-|-|-||
        |1|2|3|
        """
        let document = Document(parsing: source)
        let formatted = document.format()
        XCTAssertEqual(source, formatted)
    }
}

class MarkupFormatterMixedContentTests: XCTestCase {
    func testMixedContentWithBlockDirectives() {
        let expected = [
            #"""
            # Example title

            @Metadata {
                @TitleHeading(example)
            }
            """#,
            #"""
            @Tutorials(name: Foo) {
                @Intro(title: Bar) {
                    Foobar
                    
                    @Image(source: foo, alt: bar)
                }
            }
            """#,
            #"""
            # Example title

            @Links(visualStyle: list) {
                - ``Foo``
                - ``Bar``
            }
            """#,
        ]
        let printed = [
            Document(
                Heading(level: 1, Text("Example title")),
                BlockDirective(name: "Metadata", children: [
                    BlockDirective(name: "TitleHeading", argumentText: "example"),
                ])
            ).format(),
            Document(
                BlockDirective(name: "Tutorials", argumentText: "name: Foo", children: [
                    BlockDirective(name: "Intro", argumentText: "title: Bar", children: [
                        Paragraph(Text("Foobar")) as BlockMarkup,
                        BlockDirective(name: "Image", argumentText: "source: foo, alt: bar") as BlockMarkup,
                    ]),
                ])
            ).format(),
            Document(
                Heading(level: 1, Text("Example title")),
                BlockDirective(name: "Links", argumentText: "visualStyle: list", children: [
                    UnorderedList([
                        ListItem(Paragraph(SymbolLink(destination: "Foo"))),
                        ListItem(Paragraph(SymbolLink(destination: "Bar"))),
                    ]),
                ])
            ).format(),
        ]
        zip(expected, printed).forEach { XCTAssertEqual($0, $1) }
    }

    func testDoxygenCommandsPrecedingNewlinesWithSingleNewline() {
        let expected = #"""
            Does something.

            \abstract abstract
            \param x first param
            \returns result
            \note note
            \discussion discussion
            """#

        let formattingOptions = MarkupFormatter.Options(
            adjacentDoxygenCommandsSpacing: .singleNewline)
        let printed = Document(
            Paragraph(Text("Does something.")),
            DoxygenAbstract(children: Paragraph(Text("abstract"))),
            DoxygenParameter(name: "x", children: Paragraph(Text("first param"))),
            DoxygenReturns(children: Paragraph(Text("result"))),
            DoxygenNote(children: Paragraph(Text("note"))),
            DoxygenDiscussion(children: Paragraph(Text("discussion")))
        ).format(options: formattingOptions)

        XCTAssertEqual(expected, printed)
    }

    func testDoxygenCommandsPrecedingNewlinesAsSeparateParagraphs() {
        let expected = #"""
            Does something.

            \abstract abstract

            \param x first param

            \returns result

            \note note

            \discussion discussion
            """#

        let formattingOptions = MarkupFormatter.Options(
            adjacentDoxygenCommandsSpacing: .separateParagraphs)
        let printed = Document(
            Paragraph(Text("Does something.")),
            DoxygenAbstract(children: Paragraph(Text("abstract"))),
            DoxygenParameter(name: "x", children: Paragraph(Text("first param"))),
            DoxygenReturns(children: Paragraph(Text("result"))),
            DoxygenNote(children: Paragraph(Text("note"))),
            DoxygenDiscussion(children: Paragraph(Text("discussion")))
        ).format(options: formattingOptions)

        XCTAssertEqual(expected, printed)
    }
}
