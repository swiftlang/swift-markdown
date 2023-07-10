/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class HTMLFormatterTests: XCTestCase {
    func testFormatEverything() {
        let expectedDump = """
        <h1>Header</h1>
        <p><em>Emphasized</em> <strong>strong</strong> <code>inline code</code> <a href="foo">link</a> <img src="foo" title="" />.</p>
        <ul>
        <li><p>this</p>
        </li>
        <li><p>is</p>
        </li>
        <li><p>a</p>
        </li>
        <li><p>list</p>
        </li>
        </ul>
        <ol>
        <li><p>eggs</p>
        </li>
        <li><p>milk</p>
        </li>
        </ol>
        <blockquote>
        <p>BlockQuote</p>
        </blockquote>
        <ol start="2">
        <li><p>flour</p>
        </li>
        <li><p>sugar</p>
        </li>
        </ol>
        <ul>
        <li><input type="checkbox" disabled="" checked="" /> <p>Combine flour and baking soda.</p>
        </li>
        <li><input type="checkbox" disabled="" /> <p>Combine sugar and eggs.</p>
        </li>
        </ul>
        <pre><code class="language-swift">func foo() {
            let x = 1
        }
        </code></pre>
        <pre><code>// Is this real code? Or just fantasy?
        </code></pre>
        <p>This is an <a href="topic://autolink">topic://autolink</a>.</p>
        <hr />
        <a href="foo.png">
        An HTML Block.
        </a>
        <p>This is some <p>inline html</p>.</p>
        <p>line<br />
        break</p>
        <p>soft
        break</p>
        <!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

        """ // The rendered output contains a trailing newline

        XCTAssertEqual(HTMLFormatter.format(everythingDocument), expectedDump)
    }

    func testFormatAsides() {
        let inputText = """
        > This is a regular block quote.

        > Note: This is actually an aside.
        """

        let expectedOutput = """
        <blockquote>
        <p>This is a regular block quote.</p>
        </blockquote>
        <aside data-kind="Note">
        <p>This is actually an aside.</p>
        </aside>

        """

        XCTAssertEqual(HTMLFormatter.format(inputText, options: [.parseAsides]), expectedOutput)
    }

    // JSON5 parsing (which allows property names without quotes) is only available in Apple Foundation
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    func testInlineAttributesJSON5() {
        if #unavailable(macOS 12, iOS 15, tvOS 15, watchOS 8) {
            return
        }
        let inputText = """
        ^[formatted text](class: "fancy")
        """
        let document = Document(parsing: inputText)

        do {
            let expectedOutput = """
            <p><span data-attributes="class: \\"fancy\\"">formatted text</span></p>

            """

            var visitor = HTMLFormatter()
            visitor.visit(document)

            XCTAssertEqual(HTMLFormatter.format(inputText), expectedOutput)
        }

        do {
            let expectedOutput = """
            <p><span data-attributes="class: \\"fancy\\"" class="fancy">formatted text</span></p>

            """

            XCTAssertEqual(
                HTMLFormatter.format(inputText, options: [.parseInlineAttributeClass]),
                expectedOutput
            )
        }
    }
    #endif

    func testInlineAttributes() {
        let inputText = """
        ^[formatted text]("class": "fancy")
        """
        let document = Document(parsing: inputText)

        do {
            let expectedOutput = """
            <p><span data-attributes="\\"class\\": \\"fancy\\"">formatted text</span></p>

            """

            var visitor = HTMLFormatter()
            visitor.visit(document)

            XCTAssertEqual(HTMLFormatter.format(inputText), expectedOutput)
        }

        do {
            let expectedOutput = """
            <p><span data-attributes="\\"class\\": \\"fancy\\"" class="fancy">formatted text</span></p>

            """

            XCTAssertEqual(
                HTMLFormatter.format(inputText, options: [.parseInlineAttributeClass]),
                expectedOutput
            )
        }
    }

    func testFormatTables() {
        do {
            let inputText = """
            | aaa | bbb |
            | --- | --- |
            | aaa | bbb |
            """

            let expectedOutput = """
            <table>
            <thead>
            <tr>
            <th>aaa</th>
            <th>bbb</th>
            </tr>
            </thead>
            <tbody>
            <tr>
            <td>aaa</td>
            <td>bbb</td>
            </tr>
            </tbody>
            </table>

            """

            XCTAssertEqual(HTMLFormatter.format(inputText), expectedOutput)
        }

        do {
            let inputText = """
            | aaa | bbb |
            | :-- | --: |
            | aaa | bbb |
            """

            let expectedOutput = """
            <table>
            <thead>
            <tr>
            <th align="left">aaa</th>
            <th align="right">bbb</th>
            </tr>
            </thead>
            <tbody>
            <tr>
            <td align="left">aaa</td>
            <td align="right">bbb</td>
            </tr>
            </tbody>
            </table>

            """

            XCTAssertEqual(HTMLFormatter.format(inputText), expectedOutput)
        }

        do {
            let inputText = """
            | one | two |
            | --- | --- |
            | hello    ||
            """

            let expectedOutput = """
            <table>
            <thead>
            <tr>
            <th>one</th>
            <th>two</th>
            </tr>
            </thead>
            <tbody>
            <tr>
            <td colspan="2">hello</td>
            </tr>
            </tbody>
            </table>

            """

            XCTAssertEqual(HTMLFormatter.format(inputText), expectedOutput)
        }

        do {
            let inputText = """
            | one | two   |
            | --- | ---   |
            | big | small |
            | ^   | small |
            """

            let expectedOutput = """
            <table>
            <thead>
            <tr>
            <th>one</th>
            <th>two</th>
            </tr>
            </thead>
            <tbody>
            <tr>
            <td rowspan="2">big</td>
            <td>small</td>
            </tr>
            <tr>
            <td>small</td>
            </tr>
            </tbody>
            </table>

            """

            XCTAssertEqual(HTMLFormatter.format(inputText), expectedOutput)
        }

        do {
            let inputText = """
            | one | two | three |
            | --- | --- | ----- |
            | big      || small |
            | ^        || small |
            """

            let expectedOutput = """
            <table>
            <thead>
            <tr>
            <th>one</th>
            <th>two</th>
            <th>three</th>
            </tr>
            </thead>
            <tbody>
            <tr>
            <td rowspan="2" colspan="2">big</td>
            <td>small</td>
            </tr>
            <tr>
            <td>small</td>
            </tr>
            </tbody>
            </table>

            """

            XCTAssertEqual(HTMLFormatter.format(inputText), expectedOutput)
        }
    }
}
