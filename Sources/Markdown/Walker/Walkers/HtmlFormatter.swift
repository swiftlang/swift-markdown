/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

public struct HtmlFormatter: MarkupWalker {
    public var result = ""

    var inTableHead = false
    var tableColumnAlignments: [Table.ColumnAlignment?]? = nil
    var currentTableColumn = 0

    public init() {}

    // MARK: Block elements

    public mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> () {
        // TODO: attempt to parse this as an aside and handle it differently
        result += "<blockquote>\n"
        descendInto(blockQuote)
        result += "</blockquote>\n"
    }

    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
        let languageAttr: String
        if let language = codeBlock.language {
            languageAttr = " class=\"language-\(language)\""
        } else {
            languageAttr = ""
        }
        result += "<pre><code\(languageAttr)>\(codeBlock.code)</code></pre>\n"
    }

    public mutating func visitHeading(_ heading: Heading) -> () {
        result += "<h\(heading.level)>\(heading.plainText)</h\(heading.level)>\n"
    }

    public mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> () {
        result += "<hr />\n"
    }

    public mutating func visitHTMLBlock(_ html: HTMLBlock) -> () {
        result += html.rawHTML
        result += "\n"
    }

    public mutating func visitListItem(_ listItem: ListItem) -> () {
        result += "<li>"
        descendInto(listItem)
        result += "</li>\n"
    }

    public mutating func visitOrderedList(_ orderedList: OrderedList) -> () {
        let start: String
        if orderedList.startIndex != 1 {
            start = " start=\"\(orderedList.startIndex)\""
        } else {
            start = ""
        }
        result += "<ol\(start)>\n"
        descendInto(orderedList)
        result += "</ol>\n"
    }

    public mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> () {
        result += "<ul>\n"
        descendInto(unorderedList)
        result += "</ul>\n"
    }

    public mutating func visitParagraph(_ paragraph: Paragraph) -> () {
        result += "<p>"
        descendInto(paragraph)
        result += "</p>\n"
    }

    public mutating func visitTable(_ table: Table) -> () {
        result += "<table>\n"
        tableColumnAlignments = table.columnAlignments
        descendInto(table)
        tableColumnAlignments = nil
        result += "</table>\n"
    }

    public mutating func visitTableHead(_ tableHead: Table.Head) -> () {
        result += "<thead>\n"
        result += "<tr>\n"

        inTableHead = true
        currentTableColumn = 0
        descendInto(tableHead)
        inTableHead = false

        result += "</tr>\n"
        result += "</thead>\n"
    }

    public mutating func visitTableBody(_ tableBody: Table.Body) -> () {
        if !tableBody.isEmpty {
            result += "<tbody>\n"
            descendInto(tableBody)
            result += "</tbody>\n"
        }
    }

    public mutating func visitTableRow(_ tableRow: Table.Row) -> () {
        result += "<tr>\n"

        currentTableColumn = 0
        descendInto(tableRow)

        result += "</tr>\n"
    }

    public mutating func visitTableCell(_ tableCell: Table.Cell) -> () {
        guard let alignments = tableColumnAlignments, currentTableColumn < alignments.count else { return }

        let element: String
        if inTableHead {
            element = "th"
        } else {
            element = "td"
        }

        if inTableHead {
            result += "<\(element)"
        } else {
            result += "<\(element)"
        }

        if let alignment = alignments[currentTableColumn] {
            result += " align=\"\(alignment)\""
        }
        currentTableColumn += 1

        if tableCell.rowspan > 1 {
            result += " rowspan=\"\(tableCell.rowspan)\""
        }
        if tableCell.colspan > 1 {
            result += " colspan=\"\(tableCell.colspan)\""
        }

        result += ">"

        descendInto(tableCell)

        result += "</\(element)>\n"
    }

    // MARK: Inline elements

    mutating func printInline(tag: String, content: String) {
        result += "<\(tag)>\(content)</\(tag)>"
    }

    mutating func printInline(tag: String, _ inline: InlineMarkup) {
        printInline(tag: tag, content: inline.plainText)
    }

    public mutating func visitInlineCode(_ inlineCode: InlineCode) -> () {
        printInline(tag: "code", content: inlineCode.code)
    }

    public mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
        printInline(tag: "em", emphasis)
    }

    public mutating func visitStrong(_ strong: Strong) -> () {
        printInline(tag: "strong", strong)
    }

    public mutating func visitImage(_ image: Image) -> () {
        result += "<img"

        if let source = image.source {
            result += " src=\"\(source)\""
        }

        if let title = image.title {
            result += " title=\"\(title)\""
        }

        result += " />"
    }

    public mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> () {
        result += inlineHTML.rawHTML
    }

    public mutating func visitLineBreak(_ lineBreak: LineBreak) -> () {
        result += "<br />\n"
    }

    public mutating func visitSoftBreak(_ softBreak: SoftBreak) -> () {
        result += "\n"
    }

    public mutating func visitLink(_ link: Link) -> () {
        result += "<a"
        if let destination = link.destination {
            result += " href=\"\(destination)\""
        }
        result += ">"

        descendInto(link)

        result += "</a>"
    }

    public mutating func visitText(_ text: Text) -> () {
        result += text.string
    }

    public mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> () {
        printInline(tag: "del", strikethrough)
    }

    public mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> () {
        if let destination = symbolLink.destination {
            printInline(tag: "code", content: destination)
        }
    }

    public mutating func visitInlineAttributes(_ attributes: InlineAttributes) -> () {
        // TODO: it would be cool to attempt to parse the attributes, look for `class` and set that separately
        result += "<span data-attributes=\"\(attributes.attributes)>"
        descendInto(attributes)
        result += "</span>"
    }
}
