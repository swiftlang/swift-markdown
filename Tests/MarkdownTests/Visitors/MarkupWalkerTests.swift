/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class MarkupWalkerTests: XCTestCase {
    /// Test that every element is visited via `defaultVisit`
    func testDefaultVisit() {
        struct CountEveryElement: MarkupWalker {
            var count = 0
            mutating func defaultVisit(_ markup: Markup) {
                count += 1
                descendInto(markup)
            }
        }

        var counter = CountEveryElement()
        counter.visit(everythingDocument)
        counter.visit(CustomInline(""))
        XCTAssertEqual(everythingDocument.subtreeCount + 1, counter.count)
    }

    /// Test that every element is visited via a customization of each visit method.
    func testVisitsEveryElement() {
        struct CountEveryElement: MarkupWalker {
            var count = 0
            mutating func visitLink(_ link: Link) -> () {
                count += 1
                descendInto(link)
            }
            mutating func visitText(_ text: Text) -> () {
                count += 1
                descendInto(text)
            }
            mutating func visitImage(_ image: Image) -> () {
                count += 1
                descendInto(image)
            }
            mutating func visitStrong(_ strong: Strong) -> () {
                count += 1
                descendInto(strong)
            }
            mutating func visitHeading(_ heading: Heading) -> () {
                count += 1
                descendInto(heading)
            }
            mutating func visitHTMLBlock(_ html: HTMLBlock) -> () {
                count += 1
                descendInto(html)
            }
            mutating func visitDocument(_ document: Document) -> () {
                count += 1
                descendInto(document)
            }
            mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
                count += 1
                descendInto(emphasis)
            }
            mutating func visitListItem(_ listItem: ListItem) -> () {
                count += 1
                descendInto(listItem)
            }
            mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
                count += 1
                descendInto(codeBlock)
            }
            mutating func visitLineBreak(_ lineBreak: LineBreak) -> () {
                count += 1
                descendInto(lineBreak)
            }
            mutating func visitParagraph(_ paragraph: Paragraph) -> () {
                count += 1
                descendInto(paragraph)
            }
            mutating func visitSoftBreak(_ softBreak: SoftBreak) -> () {
                count += 1
                descendInto(softBreak)
            }
            mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> () {
                count += 1
                descendInto(blockQuote)
            }
            mutating func visitInlineCode(_ inlineCode: InlineCode) -> () {
                count += 1
                descendInto(inlineCode)
            }
            mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> () {
                count += 1
                descendInto(inlineHTML)
            }
            mutating func visitCustomBlock(_ customBlock: CustomBlock) -> () {
                count += 1
                descendInto(customBlock)
            }
            mutating func visitOrderedList(_ orderedList: OrderedList) -> () {
                count += 1
                descendInto(orderedList)
            }
            mutating func visitCustomInline(_ customInline: CustomInline) -> () {
                count += 1
                descendInto(customInline)
            }
            mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> () {
                count += 1
                descendInto(thematicBreak)
            }
            mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> () {
                count += 1
                descendInto(unorderedList)
            }
        }

        var counter = CountEveryElement()
        counter.visit(everythingDocument)
        counter.visit(CustomInline(""))
        XCTAssertEqual(everythingDocument.subtreeCount + 1, counter.count)
    }
}
