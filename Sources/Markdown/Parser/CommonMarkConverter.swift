/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import cmark_gfm
import cmark_gfm_extensions
import Foundation

/// String-based CommonMark node type identifiers.
///
/// CommonMark node types do have a raw-value enum `cmark_node_type`.
/// However, in light of extensions, these enum values are not public and
/// must use strings instead to identify types.
///
/// For example, consider the task list item:
///
/// ```markdown
/// - [x] Completed
/// ```
///
/// This internally reuses the regular `CMARK_NODE_ITEM` enum type but will
/// return the type name string "tasklist" or "item" depending on whether
/// there was a `[ ]` or `[x]` after the list marker.
/// So, the raw `cmark_node_type` is no longer reliable on its own, unfortunately.
///
/// These values are taken from the `cmark_node_get_type_string` implementation
/// in the underlying cmark dependency.
///
/// > Warning: **Do not make these public.**.
fileprivate enum CommonMarkNodeType: String {
    case document
    case blockQuote = "block_quote"
    case list
    case item
    case codeBlock = "code_block"
    case htmlBlock = "html_block"
    case customBlock = "custom_block"
    case paragraph
    case heading
    case thematicBreak = "thematic_break"
    case text
    case softBreak = "softbreak"
    case lineBreak = "linebreak"
    case code
    case html = "html_inline"
    case customInline = "custom_inline"
    case emphasis = "emph"
    case strong
    case link
    case image
    case none = "NONE"
    case unknown = "<unknown>"

    // Extensions

    case strikethrough

    case table
    case tableHead = "table_header"
    case tableRow = "table_row"
    case tableCell = "table_cell"

    case taskListItem = "tasklist"
}

/// Represents the result of a cmark conversion: the current `MarkupConverterState` and the resulting converted node.
fileprivate struct MarkupConversion<Result> {
    let state: MarkupConverterState
    let result: Result
}

/// Represents the current state of cmark -> `Markup` conversion.
fileprivate struct MarkupConverterState {
    fileprivate struct PendingTableBody {
        var range: SourceRange?
    }
    /// The original source whose conversion created this state.
    let source: URL?

    /// An opaque pointer to a `cmark_iter` used during parsing.
    let iterator: UnsafeMutablePointer<cmark_iter>?

    /// The last `cmark_event_type` during parsing.
    let event: cmark_event_type

    /// An opaque pointer to the last parsed `cmark_node`.
    let node: UnsafeMutablePointer<cmark_node>?

    /// Options to consider when converting to `Markup` elements.
    let options: ParseOptions

    private(set) var headerSeen: Bool
    private(set) var pendingTableBody: PendingTableBody?

    init(source: URL?, iterator: UnsafeMutablePointer<cmark_iter>?, event: cmark_event_type, node: UnsafeMutablePointer<cmark_node>?, options: ParseOptions, headerSeen: Bool, pendingTableBody: PendingTableBody?) {
        self.source = source
        self.iterator = iterator
        self.event = event
        self.node = node
        self.options = options
        self.headerSeen = headerSeen
        self.pendingTableBody = pendingTableBody

        switch (event, nodeType) {
        case (CMARK_EVENT_EXIT, .tableHead):
            self.headerSeen = true
        case (CMARK_EVENT_ENTER, .tableRow) where headerSeen:
            if self.pendingTableBody == nil {
                self.pendingTableBody = PendingTableBody(range: self.range(self.node))
                precondition(self.pendingTableBody != nil)
            }
        case (CMARK_EVENT_EXIT, .table):
            if let endOfTable = self.range(self.node)?.upperBound,
               let pendingTableRange = self.pendingTableBody?.range {
                self.pendingTableBody?.range = pendingTableRange.lowerBound..<endOfTable
            }
        default:
            break
        }
    }

    /// Get the next cmark iterator and node, returning a new state.
    func next(clearPendingTableBody: Bool = false) -> MarkupConverterState {
        let newEvent = cmark_iter_next(iterator)
        let newNode = cmark_iter_get_node(iterator)
        return MarkupConverterState(source: source, iterator: iterator, event: newEvent, node: newNode, options: options, headerSeen: clearPendingTableBody ? false : headerSeen, pendingTableBody: clearPendingTableBody ? nil : pendingTableBody)
    }

    /// The type of the last parsed cmark node.
    var nodeType: CommonMarkNodeType {
        let typeString = String(cString: cmark_node_get_type_string(node))
        guard let type = CommonMarkNodeType(rawValue: typeString) else {
            fatalError("Unknown cmark node type '\(typeString)' encountered during conversion")
        }
        return type
    }

    /// The source range where a node occurred, according to cmark.
    func range(_ node: UnsafeMutablePointer<cmark_node>?) -> SourceRange? {
        let startLine = Int(cmark_node_get_start_line(node))
        let startColumn = Int(cmark_node_get_start_column(node))
        guard startLine > 0 && startColumn > 0 else {
            // cmark doesn't track the positions for this node.
            return nil
        }

        let endLine = Int(cmark_node_get_end_line(node))
        let endColumn = Int(cmark_node_get_end_column(node)) + 1

        guard endLine > 0 && endColumn > 0 else {
            // cmark doesn't track the positions for this node.
            return nil
        }

        // If this is a symbol link / code span, set the locations to include the ticks.
        let backtickCount = Int(cmark_node_get_backtick_count(node))

        let start = SourceLocation(line: startLine, column: startColumn - backtickCount, source: source)
        let end = SourceLocation(line: endLine, column: endColumn + backtickCount, source: source)

        // Sometimes the cmark range is invalid (rdar://73376719)
        guard start <= end else { return nil }
        return start..<end
    }
}

/// Parses markup source and returns a `Markup` node representing the parsed source.
struct MarkupParser {
    /// Dispatches into specific conversion methods from every kind of cmark element, returning the resulting `RawMarkup`.
    private static func convertAnyElement(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)

        switch state.nodeType {
        case .document:
            return convertDocument(state)
        case .blockQuote:
            return convertBlockQuote(state)
        case .list:
            return convertList(state)
        case .item:
            return convertListItem(state)
        case .codeBlock:
            return convertCodeBlock(state)
        case .htmlBlock:
            return convertHTMLBlock(state)
        case .customBlock:
            return convertCustomBlock(state)
        case .paragraph:
            return convertParagraph(state)
        case .heading:
            return convertHeading(state)
        case .thematicBreak:
            return convertThematicBreak(state)
        case .text:
            return convertText(state)
        case .softBreak:
            return convertSoftBreak(state)
        case .lineBreak:
            return convertLineBreak(state)
        case .code:
            return convertInlineCode(state)
        case .html:
            return convertInlineHTML(state)
        case .customInline:
            return convertCustomInline(state)
        case .emphasis:
            return convertEmphasis(state)
        case .strong:
            return convertStrong(state)
        case .link:
            return convertLink(state)
        case .image:
            return convertImage(state)
        case .strikethrough:
            return convertStrikethrough(state)
        case .taskListItem:
            return convertTaskListItem(state)
        case .table:
            return convertTable(state)
        case .tableHead:
            return convertTableHeader(state)
        case .tableRow:
            return convertTableRow(state)
        case .tableCell:
            return convertTableCell(state)
        default:
            fatalError("Unknown cmark node type '\(state.nodeType.rawValue)' encountered during conversion")
        }
    }

    /// Returns the raw literal text for a cmark node.
    ///
    /// - parameter node: An opaque pointer to a `cmark_node`.
    private static func getLiteralContent(node: UnsafeMutablePointer<cmark_node>!) -> String {
        guard let rawText = cmark_node_get_literal(node) else {
            fatalError("Expected literal content for cmark node but got null pointer")
        }
        return String(cString: rawText)
    }

    /// Converts the children of the given state's cmark node and return them all.
    ///
    /// - parameter originalState: The state containing the node whose children you want to convert.
    /// - returns: A new conversion containing all of the node's converted children.
    private static func convertChildren(_ originalState: MarkupConverterState) -> MarkupConversion<[RawMarkup]> {
        let root = originalState.node
        var state = originalState.next()
        var layout = [RawMarkup]()

        while state.node != root && state.event != CMARK_EVENT_EXIT {
            let conversion = convertAnyElement(state)
            layout.append(conversion.result)
            state = conversion.state
        }
        return MarkupConversion(state: state, result: layout)
    }

    private static func convertDocument(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .document)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        precondition(childConversion.state.node == state.node)
        return MarkupConversion(state: childConversion.state.next(), result: .document(parsedRange: parsedRange, childConversion.result))
    }

    private static func convertBlockQuote(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .blockQuote)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .blockQuote(parsedRange: parsedRange, childConversion.result))
    }

    private static func convertList(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .list)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)

        for child in childConversion.result {
            guard case .listItem = child.data else {
                fatalError("Converted cmark list had a node other than RawMarkup.listItem")
            }
        }

        switch cmark_node_get_list_type(state.node) {
        case CMARK_BULLET_LIST:
            return MarkupConversion(state: childConversion.state.next(), result: .unorderedList(parsedRange: parsedRange, childConversion.result))
        case CMARK_ORDERED_LIST:
            return MarkupConversion(state: childConversion.state.next(), result: .orderedList(parsedRange: parsedRange, childConversion.result))
        default:
            fatalError("cmark reported a list node but said its list type is CMARK_NO_LIST?")
        }
    }

    private static func convertListItem(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .item)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .listItem(checkbox: .none, parsedRange: parsedRange, childConversion.result))
    }

    private static func convertCodeBlock(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .codeBlock)
        let parsedRange = state.range(state.node)
        let language = String(cString: cmark_node_get_fence_info(state.node))
        let code = getLiteralContent(node: state.node)

        return MarkupConversion(state: state.next(), result: .codeBlock(parsedRange: parsedRange, code: code, language: language.isEmpty ? nil : language))
    }

    private static func convertHTMLBlock(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .htmlBlock)
        let parsedRange = state.range(state.node)
        let html = getLiteralContent(node: state.node)
        return MarkupConversion(state: state.next(), result: .htmlBlock(parsedRange: parsedRange, html: html))
    }

    private static func convertCustomBlock(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .customBlock)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .customBlock(parsedRange: parsedRange, childConversion.result))
    }

    private static func convertParagraph(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .paragraph)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .paragraph(parsedRange: parsedRange, childConversion.result))
    }

    private static func convertHeading(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .heading)
        let parsedRange = state.range(state.node)
        let headingLevel = Int(cmark_node_get_heading_level(state.node))
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .heading(level: headingLevel, parsedRange: parsedRange, childConversion.result))
    }

    private static func convertThematicBreak(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .thematicBreak)
        let parsedRange = state.range(state.node)
        return MarkupConversion(state: state.next(), result: .thematicBreak(parsedRange: parsedRange))
    }

    private static func convertText(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .text)
        let parsedRange = state.range(state.node)
        let string = getLiteralContent(node: state.node)
        return MarkupConversion(state: state.next(), result: .text(parsedRange: parsedRange, string: string))
    }

    private static func convertSoftBreak(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .softBreak)
        let parsedRange = state.range(state.node)
        return MarkupConversion(state: state.next(), result: .softBreak(parsedRange: parsedRange))
    }

    private static func convertLineBreak(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .lineBreak)
        let parsedRange = state.range(state.node)
        return MarkupConversion(state: state.next(), result: .lineBreak(parsedRange: parsedRange))
    }

    private static func convertInlineCode(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .code)
        let parsedRange = state.range(state.node)
        let literalContent = getLiteralContent(node: state.node)
        if state.options.contains(.parseSymbolLinks),
           cmark_node_get_backtick_count(state.node) > 1 {
            return MarkupConversion(state: state.next(), result: .symbolLink(parsedRange: parsedRange, destination: literalContent))
        } else {
            return MarkupConversion(state: state.next(), result: .inlineCode(parsedRange: parsedRange, code: literalContent))
        }
    }

    private static func convertInlineHTML(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .html)
        let parsedRange = state.range(state.node)
        let html = getLiteralContent(node: state.node)
        return MarkupConversion(state: state.next(), result: .inlineHTML(parsedRange: parsedRange, html: html))
    }

    private static func convertCustomInline(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .customInline)
        let parsedRange = state.range(state.node)
        let text = getLiteralContent(node: state.node)
        return MarkupConversion(state: state.next(), result: .customInline(parsedRange: parsedRange, text: text))
    }

    private static func convertEmphasis(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .emphasis)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .emphasis(parsedRange: parsedRange, childConversion.result))
    }

    private static func convertStrong(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .strong)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .strong(parsedRange: parsedRange, childConversion.result))
    }

    private static func convertLink(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .link)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        let destination = String(cString: cmark_node_get_url(state.node))
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .link(destination: destination, parsedRange: parsedRange, childConversion.result))
    }

    private static func convertImage(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .image)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        let destination = String(cString: cmark_node_get_url(state.node))
        let title = String(cString: cmark_node_get_title(state.node))
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .image(source: destination, title: title, parsedRange: parsedRange, childConversion.result))
    }

    private static func convertStrikethrough(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .strikethrough)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .strikethrough(parsedRange: parsedRange, childConversion.result))
    }

    private static func convertTaskListItem(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .taskListItem)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        let checkbox: Checkbox = cmark_gfm_extensions_get_tasklist_item_checked(state.node) ? .checked : .unchecked
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .listItem(checkbox: checkbox, parsedRange: parsedRange, childConversion.result))
    }

    private static func convertTable(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .table)
        let parsedRange = state.range(state.node)
        let columnCount = Int(cmark_gfm_extensions_get_table_columns(state.node))
        let columnAlignments = (0..<columnCount).map { column -> Table.ColumnAlignment? in
            // cmark tracks left, center, and right alignments as the ASCII
            // characters 'l', 'c', and 'r'.
            let ascii = cmark_gfm_extensions_get_table_alignments(state.node)[column]
            let scalar = UnicodeScalar(ascii)
            let character = Character(scalar)
            switch character {
            case "l":
                return .left
            case "r":
                return .right
            case "c":
                return .center
            case "\0":
                return nil
            default:
                fatalError("Unexpected table column character for cmark table: \(character) (0x\(String(ascii, radix: 16)))")
            }
        }

        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)

        var children = childConversion.result

        let header: RawMarkup
        if let firstChild = children.first,
           case .tableHead = firstChild.data {
            header = firstChild
            children.removeFirst()
        } else {
            header = .tableHead(parsedRange: nil, columns: [])
        }

        if children.isEmpty {
            precondition(childConversion.state.pendingTableBody == nil)
        }

        let body: RawMarkup
        if !children.isEmpty {
            let pendingBody = childConversion.state.pendingTableBody!
            body = RawMarkup.tableBody(parsedRange: pendingBody.range, rows: children)
        } else {
            body = .tableBody(parsedRange: nil, rows: [])
        }

        return MarkupConversion(state: childConversion.state.next(clearPendingTableBody: true),
                                result: .table(columnAlignments: columnAlignments,
                                               parsedRange: parsedRange,
                                               header: header,
                                               body: body))
    }

    private static func convertTableHeader(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .tableHead)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .tableHead(parsedRange: parsedRange, columns: childConversion.result))
    }

    private static func convertTableRow(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .tableRow)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .tableRow(parsedRange: parsedRange, childConversion.result))
    }

    private static func convertTableCell(_ state: MarkupConverterState) -> MarkupConversion<RawMarkup> {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .tableCell)
        let parsedRange = state.range(state.node)
        let childConversion = convertChildren(state)
        precondition(childConversion.state.node == state.node)
        precondition(childConversion.state.event == CMARK_EVENT_EXIT)
        return MarkupConversion(state: childConversion.state.next(), result: .tableCell(parsedRange: parsedRange, childConversion.result))
    }

    static func parseString(_ string: String, source: URL?, options: ParseOptions) -> Document {
        cmark_gfm_core_extensions_ensure_registered()
        let parser = cmark_parser_new(CMARK_OPT_SMART)
        cmark_parser_attach_syntax_extension(parser, cmark_find_syntax_extension("table"))
        cmark_parser_attach_syntax_extension(parser, cmark_find_syntax_extension("strikethrough"))
        cmark_parser_attach_syntax_extension(parser, cmark_find_syntax_extension("tasklist"))
        cmark_parser_feed(parser, string, string.utf8.count)
        let rawDocument = cmark_parser_finish(parser)
        let initialState = MarkupConverterState(source: source, iterator: cmark_iter_new(rawDocument), event: CMARK_EVENT_NONE, node: nil, options: options, headerSeen: false, pendingTableBody: nil).next()
        precondition(initialState.event == CMARK_EVENT_ENTER)
        precondition(initialState.nodeType == .document)
        let conversion = convertAnyElement(initialState)
        guard case .document = conversion.result.data else {
            fatalError("cmark top-level conversion didn't produce a RawMarkup.document")
        }

        let finalState = conversion.state.next()
        precondition(finalState.event == CMARK_EVENT_DONE)
        precondition(finalState.node == nil)
        precondition(initialState.iterator == finalState.iterator)

        precondition(initialState.node != nil)

        cmark_node_free(initialState.node)
        cmark_iter_free(finalState.iterator)
        cmark_parser_free(parser)

        let data = _MarkupData(AbsoluteRawMarkup(markup: conversion.result,
                                                metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0)))
        return makeMarkup(data) as! Document
    }
}

