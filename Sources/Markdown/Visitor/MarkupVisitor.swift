/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// Visits `Markup` elements and returns a result.
///
/// - note: This interface only provides requirements for visiting each kind of element. It does not require each visit method to descend into child elements.
///
/// Generally, ``MarkupWalker`` is best for walking a ``Markup`` tree if the ``Result`` type is `Void` or is built up some other way, or ``MarkupRewriter`` for recursively changing a tree's structure. This type serves as a common interface to both. However, for building up other structured result types you can implement ``MarkupVisitor`` directly.
public protocol MarkupVisitor<Result> {

    /**
     The result type returned when visiting a element.
     */
    associatedtype Result

    /**
     A default implementation to use when a visitor method isn't implemented for a particular element.
     - parameter markup: the element to visit.
     - returns: The result of the visit.
     */
    mutating func defaultVisit(_ markup: Markup) -> Result

    /**
     Visit any kind of `Markup` element and return the result.

     - parameter markup: Any kind of `Markup` element.
     - returns: The result of the visit.
     */
    mutating func visit(_ markup: Markup) -> Result

    /**
     Visit a `BlockQuote` element and return the result.

     - parameter blockQuote: A `BlockQuote` element.
     - returns: The result of the visit.
     */
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> Result

    /**
     Visit a `CodeBlock` element and return the result.

     - parameter codeBlock: An `CodeBlock` element.
     - returns: The result of the visit.
     */
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> Result

    /**
     Visit a `CustomBlock` element and return the result.

     - parameter customBlock: An `CustomBlock` element.
     - returns: The result of the visit.
     */
    mutating func visitCustomBlock(_ customBlock: CustomBlock) -> Result

    /**
     Visit a `Document` element and return the result.

     - parameter document: An `Document` element.
     - returns: The result of the visit.
     */
    mutating func visitDocument(_ document: Document) -> Result

    /**
     Visit a `Heading` element and return the result.

     - parameter heading: An `Heading` element.
     - returns: The result of the visit.
     */
    mutating func visitHeading(_ heading: Heading) -> Result

    /**
     Visit a `ThematicBreak` element and return the result.

     - parameter thematicBreak: An `ThematicBreak` element.
     - returns: The result of the visit.
     */
    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> Result
    
    /**
     Visit an `HTML` element and return the result.

     - parameter html: An `HTML` element.
     - returns: The result of the visit.
     */
    mutating func visitHTMLBlock(_ html: HTMLBlock) -> Result

    /**
     Visit a `ListItem` element and return the result.

     - parameter listItem: An `ListItem` element.
     - returns: The result of the visit.
     */
    mutating func visitListItem(_ listItem: ListItem) -> Result

    /**
     Visit a `OrderedList` element and return the result.

     - parameter orderedList: An `OrderedList` element.
     - returns: The result of the visit.
     */
    mutating func visitOrderedList(_ orderedList: OrderedList) -> Result

    /**
     Visit a `UnorderedList` element and return the result.

     - parameter unorderedList: An `UnorderedList` element.
     - returns: The result of the visit.
     */
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> Result

    /**
     Visit a `Paragraph` element and return the result.

     - parameter paragraph: An `Paragraph` element.
     - returns: The result of the visit.
     */
    mutating func visitParagraph(_ paragraph: Paragraph) -> Result

    /**
     Visit a `BlockDirective` element and return the result.

     - parameter blockDirective: A `BlockDirective` element.
     - returns: The result of the visit.
     */
    mutating func visitBlockDirective(_ blockDirective: BlockDirective) -> Result

    /**
     Visit a `InlineCode` element and return the result.

     - parameter inlineCode: An `InlineCode` element.
     - returns: The result of the visit.
     */
    mutating func visitInlineCode(_ inlineCode: InlineCode) -> Result

    /**
     Visit a `CustomInline` element and return the result.

     - parameter customInline: An `CustomInline` element.
     - returns: The result of the visit.
     */
    mutating func visitCustomInline(_ customInline: CustomInline) -> Result

    /**
     Visit a `Emphasis` element and return the result.

     - parameter emphasis: An `Emphasis` element.
     - returns: The result of the visit.
     */
    mutating func visitEmphasis(_ emphasis: Emphasis) -> Result

    /**
     Visit a `Image` element and return the result.

     - parameter image: An `Image` element.
     - returns: The result of the visit.
     */
    mutating func visitImage(_ image: Image) -> Result

    /**
     Visit a `InlineHTML` element and return the result.

     - parameter inlineHTML: An `InlineHTML` element.
     - returns: The result of the visit.
     */
    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> Result

    /**
     Visit a `LineBreak` element and return the result.

     - parameter lineBreak: An `LineBreak` element.
     - returns: The result of the visit.
     */
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> Result

    /**
     Visit a `Link` element and return the result.

     - parameter link: An `Link` element.
     - returns: The result of the visit.
     */
    mutating func visitLink(_ link: Link) -> Result
    
    /**
     Visit a `SoftBreak` element and return the result.

     - parameter softBreak: An `SoftBreak` element.
     - returns: The result of the visit.
     */
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> Result

    /**
     Visit a `Strong` element and return the result.

     - parameter strong: An `Strong` element.
     - returns: The result of the visit.
     */
    mutating func visitStrong(_ strong: Strong) -> Result

    /**
     Visit a `Text` element and return the result.

     - parameter text: A `Text` element.
     - returns: The result of the visit.
     */
    mutating func visitText(_ text: Text) -> Result

    /**
     Visit a `Strikethrough` element and return the result.

     - parameter strikethrough: A `Strikethrough` element.
     - returns: The result of the visit.
     */
    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> Result

    /**
     Visit a `Table` element and return the result.

     - parameter table: A `Table` element.
     - returns: The result of the visit.
     */
    mutating func visitTable(_ table: Table) -> Result

    /**
     Visit a `Table.Head` element and return the result.

     - parameter tableHead: A `Table.Head` element.
     - returns: The result of the visit.
     */
    mutating func visitTableHead(_ tableHead: Table.Head) -> Result

    /**
     Visit a `Table.Body` element and return the result.

     - parameter tableBody: A `Table.Body` element.
     - returns: The result of the visit.
     */
    mutating func visitTableBody(_ tableBody: Table.Body) -> Result

    /**
     Visit a `Table.Row` element and return the result.

     - parameter tableRow: A `Table.Row` element.
     - returns: The result of the visit.
     */
    mutating func visitTableRow(_ tableRow: Table.Row) -> Result

    /**
     Visit a `Table.Cell` element and return the result.

     - parameter tableCell: A `Table.Cell` element.
     - returns: The result of the visit.
     */
    mutating func visitTableCell(_ tableCell: Table.Cell) -> Result

    /**
     Visit a `SymbolLink` element and return the result.

     - parameter symbolLink: A `SymbolLink` element.
     - returns: The result of the visit.
     */
    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> Result

    /**
    Visit an `InlineAttributes` element and return the result.

    - parameter attributes: An `InlineAttributes` element.
    - returns: The result of the visit.
     */
     mutating func visitInlineAttributes(_ attributes: InlineAttributes) -> Result

    /**
     Visit a `DoxygenDiscussion` element and return the result.

     - parameter doxygenDiscussion: A `DoxygenDiscussion` element.
     - returns: The result of the visit.
     */
    mutating func visitDoxygenDiscussion(_ doxygenDiscussion: DoxygenDiscussion) -> Result

    /**
     Visit a `DoxygenNote` element and return the result.

     - parameter doxygenNote: A `DoxygenNote` element.
     - returns: The result of the visit.
     */
    mutating func visitDoxygenNote(_ doxygenNote: DoxygenNote) -> Result

    /**
     Visit a `DoxygenAbstract` element and return the result.

     - parameter doxygenAbstract: A `DoxygenAbstract` element.
     - returns: The result of the visit.
     */
    mutating func visitDoxygenAbstract(_ doxygenAbstract: DoxygenAbstract) -> Result

    /**
     Visit a `DoxygenParam` element and return the result.

     - parameter doxygenParam: A `DoxygenParam` element.
     - returns: The result of the visit.
     */
    mutating func visitDoxygenParameter(_ doxygenParam: DoxygenParameter) -> Result

    /**
     Visit a `DoxygenReturns` element and return the result.

     - parameter doxygenReturns: A `DoxygenReturns` element.
     - returns: The result of the visit.
     */
    mutating func visitDoxygenReturns(_ doxygenReturns: DoxygenReturns) -> Result
}

extension MarkupVisitor {
    // Default implementation: call `accept` on the markup element,
    // dispatching into each leaf element's implementation, which then
    // dispatches to the correct visit___ method.
    public mutating func visit(_ markup: Markup) -> Result {
        return markup.accept(&self)
    }
    public mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> Result {
        return defaultVisit(blockQuote)
    }
    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> Result {
        return defaultVisit(codeBlock)
    }
    public mutating func visitCustomBlock(_ customBlock: CustomBlock) -> Result {
        return defaultVisit(customBlock)
    }
    public mutating func visitDocument(_ document: Document) -> Result {
        return defaultVisit(document)
    }
    public mutating func visitHeading(_ heading: Heading) -> Result {
        return defaultVisit(heading)
    }
    public mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> Result {
        return defaultVisit(thematicBreak)
    }
    public mutating func visitHTMLBlock(_ html: HTMLBlock) -> Result {
        return defaultVisit(html)
    }
    public mutating func visitListItem(_ listItem: ListItem) -> Result {
        return defaultVisit(listItem)
    }
    public mutating func visitOrderedList(_ orderedList: OrderedList) -> Result {
        return defaultVisit(orderedList)
    }
    public mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> Result {
        return defaultVisit(unorderedList)
    }
    public mutating func visitParagraph(_ paragraph: Paragraph) -> Result {
        return defaultVisit(paragraph)
    }
    public mutating func visitBlockDirective(_ blockDirective: BlockDirective) -> Result {
        return defaultVisit(blockDirective)
    }
    public mutating func visitInlineCode(_ inlineCode: InlineCode) -> Result {
        return defaultVisit(inlineCode)
    }
    public mutating func visitCustomInline(_ customInline: CustomInline) -> Result {
        return defaultVisit(customInline)
    }
    public mutating func visitEmphasis(_ emphasis: Emphasis) -> Result {
        return defaultVisit(emphasis)
    }
    public mutating func visitImage(_ image: Image) -> Result {
        return defaultVisit(image)
    }
    public mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> Result {
        return defaultVisit(inlineHTML)
    }
    public mutating func visitLineBreak(_ lineBreak: LineBreak) -> Result {
        return defaultVisit(lineBreak)
    }
    public mutating func visitLink(_ link: Link) -> Result {
        return defaultVisit(link)
    }
    public mutating func visitSoftBreak(_ softBreak: SoftBreak) -> Result {
        return defaultVisit(softBreak)
    }
    public mutating func visitStrong(_ strong: Strong) -> Result {
        return defaultVisit(strong)
    }
    public mutating func visitText(_ text: Text) -> Result {
        return defaultVisit(text)
    }
    public mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> Result {
        return defaultVisit(strikethrough)
    }
    public mutating func visitTable(_ table: Table) -> Result {
        return defaultVisit(table)
    }
    public mutating func visitTableHead(_ tableHead: Table.Head) -> Result {
        return defaultVisit(tableHead)
    }
    public mutating func visitTableBody(_ tableBody: Table.Body) -> Result {
        return defaultVisit(tableBody)
    }
    public mutating func visitTableRow(_ tableRow: Table.Row) -> Result {
        return defaultVisit(tableRow)
    }
    public mutating func visitTableCell(_ tableCell: Table.Cell) -> Result {
        return defaultVisit(tableCell)
    }
    public mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> Result {
        return defaultVisit(symbolLink)
    }
    public mutating func visitInlineAttributes(_ attributes: InlineAttributes) -> Result {
        return defaultVisit(attributes)
    }
    public mutating func visitDoxygenDiscussion(_ doxygenDiscussion: DoxygenDiscussion) -> Result {
        return defaultVisit(doxygenDiscussion)
    }
    public mutating func visitDoxygenNote(_ doxygenNote: DoxygenNote) -> Result {
        return defaultVisit(doxygenNote)
    }
    public mutating func visitDoxygenAbstract(_ doxygenAbstract: DoxygenAbstract) -> Result {
            return defaultVisit(doxygenAbstract)
    }
    public mutating func visitDoxygenParameter(_ doxygenParam: DoxygenParameter) -> Result {
        return defaultVisit(doxygenParam)
    }
    public mutating func visitDoxygenReturns(_ doxygenReturns: DoxygenReturns) -> Result {
        return defaultVisit(doxygenReturns)
    }
}
