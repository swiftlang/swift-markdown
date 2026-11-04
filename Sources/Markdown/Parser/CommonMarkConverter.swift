/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import CommonMark
import Foundation

/// Parses markup source and returns a `Markdown.Document` representing the parsed source.
///
/// This drives the pure-Swift cmark port (`CommonMark`): it parses with the same option set the C
/// path used, then recursively converts the borrowed, non-copyable `MarkdownNode` tree into an owned
/// `RawMarkup` tree. All traversal happens inside the parsed document's source-borrow scope; only
/// fully-owned `RawMarkup` (with `String`s copied out) escapes.
struct MarkupParser {

    static func parseString(_ string: String, source: URL?, options: ParseOptions) -> Document {
        // Mirror the option set the old C path always used: tables + strikethrough + tasklist
        // extensions and table spans, smart punctuation unless disabled, source positions unless
        // disabled. (Footnotes and GFM autolinks were never enabled here.)
        var cmOptions: MarkdownDocument.ParseOptions = [.tables, .strikethrough, .tasklist, .tableSpans]
        if !options.contains(.disableSmartOpts) {
            cmOptions.insert(.smart)
        }
        if !options.contains(.disableSourcePosOpts) {
            cmOptions.insert(.sourcePosition)
        }

        let raw: RawMarkup
        do {
            // cmark-swift borrows the source for the document's lifetime, so conversion happens inside
            // the nonescaping `withParsedDocument` closure; only the fully-owned `RawMarkup` tree escapes.
            raw = try MarkdownDocument.withParsedDocument(string, options: cmOptions) { document in
                convert(document.root, source: source, options: options)
            }
        } catch {
            // The only error is an internal parsing/recursion limit; produce an empty document.
            raw = .document(parsedRange: nil, [])
        }

        let data = _MarkupData(AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0)))
        return makeMarkup(data) as! Document
    }

    // MARK: - Range mapping

    /// Map a `MarkdownNode`'s source range to swift-markdown's `SourceRange`.
    ///
    /// cmark-swift already reports 1-based lines, 1-based UTF-8 **byte** columns, and an `upperBound`
    /// positioned just past the node's last byte — i.e. exactly the adjusted end the old converter
    /// produced via `endColumn + 1`. Inline code-span ranges likewise already span their backticks. So
    /// this is a straight pass-through; the only thing added is the source `URL`.
    private static func range(_ node: borrowing MarkdownNode, source: URL?) -> SourceRange? {
        guard let r = node.sourceRange else { return nil }
        let start = SourceLocation(line: r.lowerBound.line, column: r.lowerBound.column, source: source)
        let end = SourceLocation(line: r.upperBound.line, column: r.upperBound.column, source: source)
        return start..<end
    }

    // MARK: - Content readers

    /// The node's literal text (for `.text` / `.codeInline` / `.htmlInline` / code & HTML block bodies).
    private static func literal(_ node: borrowing MarkdownNode) -> String {
        switch node.stringContent {
        case .text(let s): return s
        case .codeBlock(_, let body): return body
        case .htmlBlock(let body): return body
        default: return ""
        }
    }

    /// A code block's info string (language tag), or `nil` if empty.
    private static func codeBlockLanguage(_ node: borrowing MarkdownNode) -> String? {
        if case .codeBlock(let info, _) = node.stringContent {
            return info.isEmpty ? nil : info
        }
        return nil
    }

    /// A link/image destination and title (each `nil` when empty).
    private static func linkDestinationAndTitle(_ node: borrowing MarkdownNode) -> (destination: String?, title: String?) {
        if case .link(let url, let title) = node.stringContent {
            return (url.isEmpty ? nil : url, title.isEmpty ? nil : title)
        }
        return (nil, nil)
    }

    /// An `^[…]` extended-attribute node's raw attribute string.
    private static func attributeString(_ node: borrowing MarkdownNode) -> String {
        if case .attribute(let attributes) = node.stringContent {
            return attributes
        }
        return ""
    }

    // MARK: - Tree conversion

    /// Convert the subtree rooted at `root` into `RawMarkup`.
    ///
    /// Iterative (explicit heap stack) rather than recursive: documents can nest thousands of levels
    /// deep (e.g. 15k nested block quotes), which would overflow the call stack. `accStack[d]` holds
    /// the converted children accumulated for the open ancestor at depth `d`; a node is built once all
    /// its children are collected (post-order). Tables are built atomically by `convertTable` and not
    /// descended into, since their head/body regrouping needs the original node structure.
    private static func convert(_ root: borrowing MarkdownNode, source: URL?, options: ParseOptions) -> RawMarkup {
        var accStack: [[RawMarkup]] = [[]]
        var node = copy root

        while true {
            // Descend into the first child (but never into a table — it's built atomically below).
            if !isTable(node.kind), let firstChild = node.firstChild {
                accStack.append([])
                node = firstChild
                continue
            }

            // No more descent: build this node, then advance to a sibling or close ancestors.
            while true {
                let children = accStack.removeLast()
                let raw = isTable(node.kind)
                    ? convertTable(node, parsedRange: range(node, source: source), source: source, options: options)
                    : build(node, children: children, source: source, options: options)

                if accStack.isEmpty {
                    return raw   // closed the root
                }
                accStack[accStack.count - 1].append(raw)

                if let sibling = node.next {
                    node = sibling
                    accStack.append([])
                    break   // descend into the sibling's subtree
                }
                guard let parent = node.parent else {
                    return raw
                }
                node = parent   // close the parent on the next iteration
            }
        }
    }

    private static func isTable(_ kind: MarkdownNode.Kind) -> Bool {
        if case .table = kind { return true }
        return false
    }

    /// Build one node's `RawMarkup` from its already-converted `children`. Leaf kinds ignore
    /// `children` and read their literal content directly.
    private static func build(_ node: borrowing MarkdownNode, children: [RawMarkup], source: URL?, options: ParseOptions) -> RawMarkup {
        let parsedRange = range(node, source: source)

        switch node.kind {
        // Blocks
        case .document:
            return .document(parsedRange: parsedRange, children)
        case .blockQuote:
            return .blockQuote(parsedRange: parsedRange, children)
        case .list(let info):
            switch info.kind {
            case .bullet:
                return .unorderedList(parsedRange: parsedRange, children)
            case .ordered:
                return .orderedList(parsedRange: parsedRange, children, startIndex: UInt(info.start))
            @unknown default:
                return .unorderedList(parsedRange: parsedRange, children)
            }
        case .item(let checked):
            let checkbox: Checkbox?
            switch checked {
            case .none: checkbox = nil
            case .some(true): checkbox = .checked
            case .some(false): checkbox = .unchecked
            }
            return .listItem(checkbox: checkbox, parsedRange: parsedRange, children)
        case .codeBlock:
            return .codeBlock(parsedRange: parsedRange, code: literal(node), language: codeBlockLanguage(node))
        case .htmlBlock:
            return .htmlBlock(parsedRange: parsedRange, html: literal(node))
        case .customBlock:
            return .customBlock(parsedRange: parsedRange, children)
        case .paragraph:
            return .paragraph(parsedRange: parsedRange, children)
        case .heading(let level):
            return .heading(level: level, parsedRange: parsedRange, children)
        case .thematicBreak:
            return .thematicBreak(parsedRange: parsedRange)
        case .table:
            return convertTable(node, parsedRange: parsedRange, source: source, options: options)
        case .tableRow, .tableCell:
            // Rows/cells are only reached through `convertTable`, which handles them directly.
            fatalError("table row/cell encountered outside of a table")

        // Inlines
        case .text:
            return .text(parsedRange: parsedRange, string: literal(node))
        case .softBreak:
            return .softBreak(parsedRange: parsedRange)
        case .lineBreak:
            return .lineBreak(parsedRange: parsedRange)
        case .codeInline(let backtickCount):
            let code = literal(node)
            // A double-backtick code span denotes a DocC symbol link — unless its content contains a
            // backtick, in which case the multi-backtick delimiters exist to escape backtick content
            // (code voice), not to name a symbol. See https://github.com/swiftlang/swift-markdown/issues/93.
            if options.contains(.parseSymbolLinks) && backtickCount > 1 && !code.contains("`") {
                return .symbolLink(parsedRange: parsedRange, destination: code)
            }
            return .inlineCode(parsedRange: parsedRange, code: code)
        case .htmlInline:
            return .inlineHTML(parsedRange: parsedRange, html: literal(node))
        case .customInline:
            return .customInline(parsedRange: parsedRange, text: literal(node))
        case .emphasis:
            return .emphasis(parsedRange: parsedRange, children)
        case .strong:
            return .strong(parsedRange: parsedRange, children)
        case .link:
            let (destination, title) = linkDestinationAndTitle(node)
            return .link(destination: destination, title: title, parsedRange: parsedRange, children)
        case .image:
            let (destination, title) = linkDestinationAndTitle(node)
            return .image(source: destination, title: title, parsedRange: parsedRange, children)
        case .strikethrough:
            return .strikethrough(parsedRange: parsedRange, children)
        case .attribute:
            return .inlineAttributes(attributes: attributeString(node), parsedRange: parsedRange, children)

        // Not produced by the option set used here (footnotes are never enabled).
        case .footnoteReference, .footnoteDefinition:
            fatalError("footnote nodes are not expected without footnote parsing enabled")
        @unknown default:
            fatalError("unhandled CommonMark node kind")
        }
    }

    /// Convert a `.table` node, regrouping cmark-swift's flat header/body rows into swift-markdown's
    /// `tableHead` + `tableBody` shape and deriving per-column alignments from the header cells.
    /// Tables are shallow, so cell contents are converted via the (iterative) `convert` driver.
    private static func convertTable(_ node: borrowing MarkdownNode, parsedRange: SourceRange?, source: URL?, options: ParseOptions) -> RawMarkup {
        var header: RawMarkup?
        var bodyRows: [RawMarkup] = []
        var columnAlignments: [Table.ColumnAlignment?] = []
        // The body has no cmark node of its own, so its range is synthesized: from the first body row's
        // start to the table's end (matching cmark/swift-markdown), or nil when there are no body rows.
        var firstBodyRowStart: SourceLocation?

        node.children.forEach { row in
            let isHeaderRow: Bool
            if case .tableRow(let isHeader) = row.kind { isHeaderRow = isHeader } else { isHeaderRow = false }

            var cells: [RawMarkup] = []
            row.children.forEach { cell in
                if isHeaderRow {
                    columnAlignments.append(columnAlignment(cell.kind))
                }
                var cellChildren: [RawMarkup] = []
                cell.children.forEach { inline in
                    cellChildren.append(convert(inline, source: source, options: options))
                }
                let (columns, rows): (Int, Int)
                if case .tableCell(_, let c, let r) = cell.kind { (columns, rows) = (c, r) } else { (columns, rows) = (1, 1) }
                cells.append(.tableCell(
                    parsedRange: range(cell, source: source),
                    colspan: UInt(columns),
                    rowspan: UInt(rows),
                    cellChildren
                ))
            }

            let rowRange = range(row, source: source)
            if isHeaderRow {
                header = .tableHead(parsedRange: rowRange, columns: cells)
            } else {
                if firstBodyRowStart == nil {
                    firstBodyRowStart = rowRange?.lowerBound
                }
                bodyRows.append(.tableRow(parsedRange: rowRange, cells))
            }
        }

        let head = header ?? .tableHead(parsedRange: nil, columns: [])
        // Body spans the first body row's start through the table's end.
        let bodyRange: SourceRange?
        if let start = firstBodyRowStart, let tableEnd = parsedRange?.upperBound {
            bodyRange = start..<tableEnd
        } else {
            bodyRange = nil
        }
        let body = RawMarkup.tableBody(parsedRange: bodyRange, rows: bodyRows)
        return .table(columnAlignments: columnAlignments, parsedRange: parsedRange, header: head, body: body)
    }

    /// Map a cell kind's alignment to swift-markdown's optional `ColumnAlignment`.
    private static func columnAlignment(_ kind: MarkdownNode.Kind) -> Table.ColumnAlignment? {
        guard case .tableCell(let alignment, _, _) = kind else { return nil }
        switch alignment {
        case .none: return nil
        case .left: return .left
        case .center: return .center
        case .right: return .right
        @unknown default: return nil
        }
    }
}
