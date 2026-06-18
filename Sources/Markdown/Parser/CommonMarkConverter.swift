/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
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
    case inlineAttributes = "attribute"
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

fileprivate extension CommonMarkNodeType {
    /// Returns true when a node kind cannot have structural children.
    ///
    /// Leaf nodes are converted immediately when their ENTER event is
    /// encountered and therefore never need a `ParsingFrame`.
    var isLeaf: Bool {
        switch self {
        case .codeBlock, .htmlBlock, .thematicBreak, .text, .softBreak, .lineBreak, .code, .html, .customInline:
            return true
        default:
            return false
        }
    }
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
        guard let node = node else { return .none }
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
    
    /// Represents an active container node while iteratively converting the
    /// cmark AST into `RawMarkup`.
    private struct ParsingFrame {
        
        /// The underlying cmark node associated with this frame.
        let node: UnsafeMutablePointer<cmark_node>
        
        /// Cached node type to avoid repeated string conversions while the
        /// frame remains on the work stack.
        let nodeType: CommonMarkNodeType
        
        /// Source range reported by cmark for this node.
        let parsedRange: SourceRange?
        
        /// Converted child nodes accumulated between ENTER and EXIT events.
        var children: [RawMarkup] = []
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

    private static func convertCodeBlock(_ state: MarkupConverterState) -> RawMarkup {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .codeBlock)
        let parsedRange = state.range(state.node)
        let language = String(cString: cmark_node_get_fence_info(state.node))
        let code = getLiteralContent(node: state.node)
        return .codeBlock(parsedRange: parsedRange, code: code, language: language.isEmpty ? nil : language)
    }

    private static func convertHTMLBlock(_ state: MarkupConverterState) -> RawMarkup {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .htmlBlock)
        let parsedRange = state.range(state.node)
        let html = getLiteralContent(node: state.node)
        return .htmlBlock(parsedRange: parsedRange, html: html)
    }

    private static func convertThematicBreak(_ state: MarkupConverterState) -> RawMarkup {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .thematicBreak)
        let parsedRange = state.range(state.node)
        return .thematicBreak(parsedRange: parsedRange)
    }

    private static func convertText(_ state: MarkupConverterState) -> RawMarkup {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .text)
        let parsedRange = state.range(state.node)
        let string = getLiteralContent(node: state.node)
        return .text(parsedRange: parsedRange, string: string)
    }

    private static func convertSoftBreak(_ state: MarkupConverterState) -> RawMarkup {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .softBreak)
        let parsedRange = state.range(state.node)
        return .softBreak(parsedRange: parsedRange)
    }

    private static func convertLineBreak(_ state: MarkupConverterState) -> RawMarkup {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .lineBreak)
        let parsedRange = state.range(state.node)
        return .lineBreak(parsedRange: parsedRange)
    }

    private static func convertInlineCode(_ state: MarkupConverterState) -> RawMarkup {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .code)
        let parsedRange = state.range(state.node)
        let literalContent = getLiteralContent(node: state.node)
        if state.options.contains(.parseSymbolLinks),
           cmark_node_get_backtick_count(state.node) > 1 {
            return .symbolLink(parsedRange: parsedRange, destination: literalContent)
        } else {
            return .inlineCode(parsedRange: parsedRange, code: literalContent)
        }
    }

    private static func convertInlineHTML(_ state: MarkupConverterState) -> RawMarkup {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .html)
        let parsedRange = state.range(state.node)
        let html = getLiteralContent(node: state.node)
        return .inlineHTML(parsedRange: parsedRange, html: html)
    }

    private static func convertCustomInline(_ state: MarkupConverterState) -> RawMarkup {
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .customInline)
        let parsedRange = state.range(state.node)
        let text = getLiteralContent(node: state.node)
        return .customInline(parsedRange: parsedRange, text: text)
    }

    /// Converts a leaf cmark node directly into its corresponding `RawMarkup` representation.
    private static func createLeaf(state: MarkupConverterState) -> RawMarkup {
        switch state.nodeType {
        case .codeBlock:
            return convertCodeBlock(state)
        case .htmlBlock:
            return convertHTMLBlock(state)
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
        default:
            fatalError("Unhandled leaf node type: \(state.nodeType)")
        }
    }

    /// Converts a completed parsing frame into its corresponding `RawMarkup` node.
    ///
    /// This is called when the matching `CMARK_EVENT_EXIT` is encountered.
    /// At that point all descendant nodes have already been converted and
    /// accumulated in `frame.children`.
    private static func createContainer(frame: ParsingFrame, state: MarkupConverterState) -> RawMarkup {
        precondition(state.event == CMARK_EVENT_EXIT, "Expected EXIT event when closing a container node.")
        precondition(state.nodeType == frame.nodeType, "MarkupConverterState nodeType does not match the frame being closed.")
        let node = frame.node
        let children = frame.children
        let parsedRange = frame.parsedRange

        switch frame.nodeType {
        case .document:
            return .document(parsedRange: parsedRange, children)
        case .blockQuote:
            return .blockQuote(parsedRange: parsedRange, children)
        case .list:
            for child in children {
                guard case .listItem = child.data else { fatalError("Converted cmark list had a non-listItem node") }
            }
            switch cmark_node_get_list_type(node) {
            case CMARK_BULLET_LIST:
                return .unorderedList(parsedRange: parsedRange, children)
            case CMARK_ORDERED_LIST:
                let cmarkStart = UInt(cmark_node_get_list_start(node))
                return .orderedList(parsedRange: parsedRange, children, startIndex: cmarkStart)
            default:
                fatalError("cmark reported a list node but said its list type is CMARK_NO_LIST?")
            }
        case .item:
            return .listItem(checkbox: .none, parsedRange: parsedRange, children)
        case .customBlock:
            return .customBlock(parsedRange: parsedRange, children)
        case .paragraph:
            return .paragraph(parsedRange: parsedRange, children)
        case .heading:
            let headingLevel = Int(cmark_node_get_heading_level(node))
            return .heading(level: headingLevel, parsedRange: parsedRange, children)
        case .emphasis:
            return .emphasis(parsedRange: parsedRange, children)
        case .strong:
            return .strong(parsedRange: parsedRange, children)
        case .link:
            let destination = String(cString: cmark_node_get_url(node))
            let title = String(cString: cmark_node_get_title(node))
            return .link(destination: destination.isEmpty ? nil : destination, title: title.isEmpty ? nil : title, parsedRange: parsedRange, children)
        case .image:
            let source = String(cString: cmark_node_get_url(node))
            let title = String(cString: cmark_node_get_title(node))
            return .image(source: source.isEmpty ? nil : source, title: title.isEmpty ? nil : title, parsedRange: parsedRange, children)
        case .strikethrough:
            return .strikethrough(parsedRange: parsedRange, children)
        case .taskListItem:
            let checkbox: Checkbox = cmark_gfm_extensions_get_tasklist_item_checked(node) ? .checked : .unchecked
            return .listItem(checkbox: checkbox, parsedRange: parsedRange, children)
        case .table:
            let columnCount = Int(cmark_gfm_extensions_get_table_columns(node))
            let columnAlignments = (0..<columnCount).map { column -> Table.ColumnAlignment? in
                let ascii = cmark_gfm_extensions_get_table_alignments(node)[column]
                switch UnicodeScalar(ascii) {
                case "l": return .left
                case "r": return .right
                case "c": return .center
                case "\0": return nil
                default: fatalError("Unexpected table column character")
                }
            }

            var mutableChildren = children
            let header: RawMarkup
            // GFM tables are represented as a header followed by body rows.
            if let firstChild = mutableChildren.first, case .tableHead = firstChild.data {
                header = firstChild
                mutableChildren.removeFirst()
            } else {
                header = .tableHead(parsedRange: nil, columns: [])
            }

            if mutableChildren.isEmpty {
                precondition(state.pendingTableBody == nil)
            }
            let body = RawMarkup.tableBody(parsedRange: state.pendingTableBody?.range, rows: mutableChildren)
            return .table(columnAlignments: columnAlignments, parsedRange: parsedRange, header: header, body: body)
        case .tableHead:
            return .tableHead(parsedRange: parsedRange, columns: children)
        case .tableRow:
            return .tableRow(parsedRange: parsedRange, children)
        case .tableCell:
            let colspan = UInt(cmark_gfm_extensions_get_table_cell_colspan(node))
            let rowspan = UInt(cmark_gfm_extensions_get_table_cell_rowspan(node))
            return .tableCell(parsedRange: parsedRange, colspan: colspan, rowspan: rowspan, children)
        case .inlineAttributes:
            let attributes = String(cString: cmark_node_get_attributes(node))
            return .inlineAttributes(attributes: attributes, parsedRange: parsedRange, children)
        default:
            fatalError("Unknown container node type '\(frame.nodeType.rawValue)'")
        }
    }

    static func parseString(_ string: String, source: URL?, options: ParseOptions) -> Document {
        cmark_gfm_core_extensions_ensure_registered()

        var cmarkOptions = CMARK_OPT_TABLE_SPANS
        if !options.contains(.disableSmartOpts) {
            cmarkOptions |= CMARK_OPT_SMART
        }
        if !options.contains(.disableSourcePosOpts) {
            cmarkOptions |= CMARK_OPT_SOURCEPOS
        }
        
        let parser = cmark_parser_new(cmarkOptions)
        
        cmark_parser_attach_syntax_extension(parser, cmark_find_syntax_extension("table"))
        cmark_parser_attach_syntax_extension(parser, cmark_find_syntax_extension("strikethrough"))
        cmark_parser_attach_syntax_extension(parser, cmark_find_syntax_extension("tasklist"))
        cmark_parser_feed(parser, string, string.utf8.count)
        let rawDocument = cmark_parser_finish(parser)
        var state = MarkupConverterState(source: source, iterator: cmark_iter_new(rawDocument), event: CMARK_EVENT_NONE, node: nil, options: options, headerSeen: false, pendingTableBody: nil).next()
        
        precondition(state.event == CMARK_EVENT_ENTER)
        precondition(state.nodeType == .document)

        var stack = [ParsingFrame]()

        while state.event != CMARK_EVENT_DONE {
            guard let node = state.node else {
                state = state.next()
                continue
            }
            
            let nodeType = state.nodeType
            let parsedRange = state.range(node)

            if state.event == CMARK_EVENT_ENTER {
                if nodeType.isLeaf {
                    let leaf = createLeaf(state: state)
                    precondition(!stack.isEmpty, "Leaf node encountered without a parent document on the stack.")
                    stack[stack.count - 1].children.append(leaf)
                } else {
                    stack.append(ParsingFrame(node: node, nodeType: nodeType, parsedRange: parsedRange))
                }
                state = state.next()
                
            } else if state.event == CMARK_EVENT_EXIT {
                precondition(!nodeType.isLeaf, "cmark iterators should never return EXIT events for leaf nodes.")
                
                let frame = stack.removeLast()
                precondition(frame.node == node)
                
                let container = createContainer(frame: frame, state: state)
                
                if stack.isEmpty {
                    precondition(frame.nodeType == .document)
                    let iterator = state.iterator
                    
                    cmark_iter_free(iterator)
                    cmark_node_free(rawDocument)
                    cmark_parser_free(parser)
                    
                    let data = _MarkupData(AbsoluteRawMarkup(markup: container, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0)))
                    return makeMarkup(data) as! Document
                    
                } else {
                    stack[stack.count - 1].children.append(container)
                    state = state.next(clearPendingTableBody: nodeType == .table)
                }
            }
        }

        fatalError("cmark iteration terminated prematurely without cleanly exiting the document root.")
    }
}
