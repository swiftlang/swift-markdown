/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A borrowed view of a single node in a `MarkdownDocument`'s syntax tree.
///
/// A node can't outlive the document that produced it, and moving through the tree neither allocates nor copies. Read a node's type from `kind`, read its content from `content` or `stringContent`, and move through the tree with `children`, `firstChild`, `parent`, `next`, and `previous`.
///
/// Content accessors return information appropriate to the node's `kind`. Reading content from a node that has none yields `.none`.
public struct MarkdownNode: ~Escapable {

    internal let _view: StorageView

    internal let _index: DocumentStorage.Index

    @_lifetime(copy view)
    internal init(view: StorageView, index: DocumentStorage.Index) {
        self._view = view
        self._index = index
    }

    /// The kind of this node.
    public var kind: MarkdownNode.Kind {
        borrowing get {
            _view.record(at: _index).kind
        }
    }

    /// A Boolean value that indicates whether the node has no children.
    public var isLeaf: Bool {
        borrowing get {
            _view.record(at: _index).firstChild == nil
        }
    }

    /// A sequence over the node's children, in document order.
    public var children: Children {
        @_lifetime(borrow self)
        borrowing get {
            Children(view: _view, first: _view.record(at: _index).firstChild)
        }
    }

    /// The node's first child, or `nil` if it has no children.
    ///
    /// A navigated node shares the document's borrow, so you can store it in a `var` and reassign it, which lets you walk the tree iteratively instead of recursively.
    public var firstChild: MarkdownNode? {
        @_lifetime(copy self)
        borrowing get {
            guard let f = _view.record(at: _index).firstChild else {
                return nil
            }

            return MarkdownNode(view: _view, index: f)
        }
    }

    /// The node's parent, or `nil` if this is the document root.
    public var parent: MarkdownNode? {
        @_lifetime(copy self)
        borrowing get {
            guard let p = _view.record(at: _index).parent else {
                return nil
            }

            return MarkdownNode(view: _view, index: p)
        }
    }

    /// The next sibling, or `nil` if this is the last child of its parent.
    public var next: MarkdownNode? {
        @_lifetime(copy self)
        borrowing get {
            guard let n = _view.record(at: _index).next else {
                return nil
            }

            return MarkdownNode(view: _view, index: n)
        }
    }

    /// The previous sibling, or `nil` if this is the first child of its parent.
    public var previous: MarkdownNode? {
        @_lifetime(copy self)
        borrowing get {
            guard let p = _view.record(at: _index).previous else {
                return nil
            }

            return MarkdownNode(view: _view, index: p)
        }
    }

    // MARK: - Content
    //
    // A node's content is read through the single `content` property (see `NodeContent.swift`), which exposes borrowed spans and segment sequences in one switchable value.
}

extension MarkdownNode {
    /// A sequence of a node's children, returned by `MarkdownNode.children`.
    ///
    /// Iterate the children with `forEach(_:)`. Iteration doesn't allocate.
    public struct Children: ~Copyable, ~Escapable {

        internal let _view: StorageView

        internal let _first: DocumentStorage.Index?

        @_lifetime(copy view)
        internal init(view: StorageView, first: DocumentStorage.Index?) {
            self._view = view
            self._first = first
        }

        /// Calls `body` with each child node, in document order.
        ///
        /// Iteration uses a closure rather than `for`-`in` because a `MarkdownNode` is noncopyable and can't be produced by a standard iterator. The node passed to `body` must not escape the call.
        ///
        /// - Parameter body: A closure that receives each child node.
        public borrowing func forEach<E: Swift.Error>(_ body: (borrowing MarkdownNode) throws(E) -> Void) throws(E) {
            var current = _first
            while let valid = current {
                let node = MarkdownNode(view: _view, index: valid)
                try body(node)
                current = _view.record(at: valid).next
            }
        }
    }
}

extension MarkdownNode {
    /// The literal text of a node, as an ordered sequence of contiguous UTF-8 segments.
    ///
    /// You obtain a value of this type from the `Segments`-bearing cases of `MarkdownNode.Content`, such as `.text`, `.codeBlock`, and `.htmlBlock`. Each segment addresses the document's bytes in place, without allocating or copying. Iterate the segments with `forEach(_:)`.
    public struct Segments: ~Copyable, ~Escapable {

        internal let _view: StorageView

        internal let _ref: ContentRef

        @_lifetime(copy view)
        internal init(view: StorageView, ref: ContentRef) {
            self._view = view
            self._ref = ref
        }

        /// The number of segments (`0` for empty content; `1` for the common single-range case).
        public var count: Int {
            Int(_ref.count)
        }

        /// A Boolean value that indicates whether there is no content.
        public var isEmpty: Bool {
            _ref.count == 0
        }

        /// The total byte length across all segments.
        public var byteCount: Int {
            Int(_ref.totalLength)
        }

        /// Calls `body` with each segment, in order.
        ///
        /// Iteration uses a closure because a `UTF8Span` is noncopyable and can't be produced by a standard iterator. The span passed to `body` must not escape the call. For an owned `String` form, or to read content on an OS release without `UTF8Span`, use `MarkdownNode.stringContent`.
        ///
        /// - Parameter body: A closure that receives each segment.
        @available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
        public borrowing func forEach<E: Swift.Error>(_ body: (borrowing UTF8Span) throws(E) -> Void) throws(E) {
            for i in 0..<Int(_ref.count) {
                let segment = _view.segments[Int(_ref.first) + i]
                try body(_view.utf8Span(of: segment))
            }
        }
    }
}

extension MarkdownNode {
    /// The kind of a node in the syntax tree.
    ///
    /// Several cases carry the node's defining metadata directly as associated values - `.heading(level:)`, `.item(checked:)`, `.list(_:)`, `.codeBlock(_:)`, `.tableRow(isHeader:)`, `.tableCell(alignment:columns:rows:)`, `.codeInline(backtickCount:)`, `.footnoteReference(index:)` - so inspect a node's kind with a `switch` or `if case` rather than `==`.
    public enum Kind: Sendable, Hashable {
        // Block kinds

        /// The root of the document tree.
        case document
        /// A block quote (`>`-prefixed lines).
        case blockQuote
        /// A bullet or ordered list. The associated `ListInfo` carries the marker style, start number, and tightness.
        case list(ListInfo)
        /// A list item. `checked` is `nil` for an ordinary item, or the task-list state (`true` when checked, `false` when unchecked) when the document was parsed with `MarkdownDocument.ParseOptions.tasklist`.
        case item(checked: Bool?)
        /// A fenced or indented code block. The associated `CodeBlockInfo` describes the fence.
        case codeBlock(CodeBlockInfo)
        /// A block of raw HTML.
        case htmlBlock
        /// A custom block. Reserved; not produced by the parser.
        case customBlock
        /// A paragraph of inline content.
        case paragraph
        /// A heading. `level` is the heading level, `1` through `6`.
        case heading(level: Int)
        /// A thematic break (a horizontal rule, such as `---`).
        case thematicBreak
        /// A footnote definition (`[^label]: …`), produced when parsing with `MarkdownDocument.ParseOptions.footnotes`.
        case footnoteDefinition
        /// A GFM table, produced when parsing with `MarkdownDocument.ParseOptions.tables`.
        case table
        /// A table row. `isHeader` is `true` for the header row and `false` for a body row.
        case tableRow(isHeader: Bool)
        /// A table cell, carrying its column `alignment` and the number of `columns` and `rows` it spans.
        ///
        /// `columns` and `rows` are both `1` for an ordinary cell. Values other than `1` only arise when the document was parsed with `MarkdownDocument.ParseOptions.tableSpans` (and, for the `"` rowspan marker, `.tableRowspanDitto`): a cell that *begins* a span reports the span size (`2`, `3`, …), while a *filler* cell that merely continues a neighbour's span reports `0`.
        case tableCell(alignment: TableAlignment, columns: Int, rows: Int)

        // Inline kinds

        /// A run of literal text.
        case text
        /// A soft line break (a newline within a paragraph that renders as a space).
        case softBreak
        /// A hard line break (a line ending with two or more spaces or a backslash).
        case lineBreak
        /// Inline code span. `backtickCount` is the number of backticks in the opening/closing delimiter run (`1` for `` `x` ``, `2` for ``` ``x`` ```, …). Use it to distinguish multi-backtick spans and to widen the span's source range over its delimiters.
        case codeInline(backtickCount: Int)
        /// An inline span of raw HTML.
        case htmlInline
        /// A custom inline element. Reserved; not produced by the parser.
        case customInline
        /// Emphasized text (`*text*` or `_text_`), typically rendered italic.
        case emphasis
        /// Strongly emphasized text (`**text**` or `__text__`), typically rendered bold.
        case strong
        /// A link. The destination URL and title are available through the node's content.
        case link
        /// An image. The source URL and title are available through the node's content.
        case image
        /// A footnote reference (`[^label]`). `index` is the 1-based number assigned to the label in order of first reference - the first distinct label is `1`, the next `2`, and repeated references to the same label reuse its number. Produced when parsing with `MarkdownDocument.ParseOptions.footnotes`.
        case footnoteReference(index: Int)
        /// Struck-through text (`~text~` or `~~text~~`), produced when parsing with `MarkdownDocument.ParseOptions.strikethrough`.
        case strikethrough
        /// An extended-attribute span (`^[…]`). The raw attribute string is available through the node's content.
        case attribute
        
        /// A Boolean value that indicates whether this is a block-level kind.
        public var isBlock: Bool {
            switch self {
            case .document, .blockQuote, .list, .item, .codeBlock, .htmlBlock,
                 .customBlock, .paragraph, .heading, .thematicBreak,
                 .footnoteDefinition, .table, .tableRow, .tableCell:
                return true
            default:
                return false
            }
        }

        /// A Boolean value that indicates whether this is an inline-level kind.
        public var isInline: Bool {
            !isBlock
        }

        /// `true` for the two leaf blocks that lazily accumulate inline text (`.paragraph`, `.heading`).
        internal var canAccumulateText: Bool {
            switch self {
            case .paragraph, .heading:
                return true
            default:
                return false
            }
        }

        /// `true` for any `.codeBlock` (fenced or indented), ignoring its `CodeBlockInfo`.
        internal var isCodeBlock: Bool {
            if case .codeBlock = self {
                return true
            }
            return false
        }

        /// `true` for any `.list`, ignoring its `ListInfo`.
        internal var isList: Bool {
            if case .list = self {
                return true
            }
            return false
        }
    }

    /// Column alignment for a GFM table cell.
    public enum TableAlignment: UInt8, Sendable, Hashable {
        /// No explicit alignment (the delimiter row was `---`).
        case none
        /// Left-aligned (the delimiter row was `:---`).
        case left
        /// Center-aligned (the delimiter row was `:---:`).
        case center
        /// Right-aligned (the delimiter row was `---:`).
        case right
    }

    /// List-specific metadata exposed on `MarkdownNode.Kind.list` nodes.
    public struct ListInfo: Sendable, Hashable {
        /// Bullet vs. ordered list.
        public enum Kind: UInt8, Sendable, Hashable {
            /// An unordered list, whose items begin with a bullet marker.
            case bullet
            /// An ordered list, whose items begin with a number and delimiter.
            case ordered
        }

        /// Marker character used by a bullet-list item (`-`, `+`, or `*`).
        public enum BulletMarker: UInt8, Sendable, Hashable {
            /// A hyphen-minus marker (`-`).
            case hyphen
            /// A plus-sign marker (`+`).
            case plus
            /// An asterisk marker (`*`).
            case asterisk
        }

        /// Delimiter following an ordered-list start number (`1.` vs. `1)`).
        public enum OrderedDelimiter: UInt8, Sendable, Hashable {
            /// A period delimiter (`1.`).
            case period
            /// A closing-parenthesis delimiter (`1)`).
            case paren
        }

        /// Whether the list is a bullet or an ordered list.
        public var kind: Kind
        /// Start number for ordered lists; ignored for bullet lists.
        public var start: Int
        /// A Boolean value that indicates whether the list is tight, with no blank lines between items.
        public var tight: Bool
        /// Delimiter style for ordered lists.
        public var orderedDelimiter: OrderedDelimiter
        /// Marker character for bullet lists.
        public var bulletMarker: BulletMarker
    }

    /// Code-block metadata exposed on `MarkdownNode.Kind.codeBlock` nodes.
    public struct CodeBlockInfo: Sendable, Hashable {
        /// A Boolean value that indicates whether the block is fenced (`true`) or indented (`false`).
        public var isFenced: Bool
        /// Fence character, or `nil` for indented blocks.
        public var fenceCharacter: FenceCharacter?
        /// Number of fence characters used (3 or more); zero for indented blocks.
        public var fenceLength: Int
        /// Indentation offset of the opening fence.
        public var fenceOffset: Int
        
        /// Fence character for a code block.
        public enum FenceCharacter: UInt8, Sendable, Hashable {
            /// Code fenced with a backtick.
            case backtick
            
            /// Code fenced with a tilde.
            case tilde
            
            internal var character: UInt8 {
                switch self {
                case .backtick: UInt8(ascii: "`")
                case .tilde: UInt8(ascii: "~")
                }
            }
            
            internal init?(character: UInt8) {
                switch character {
                case UInt8(ascii: "`"): self = .backtick
                case UInt8(ascii: "~"): self = .tilde
                default:
                    return nil
                }
            }
        }
    }
}

extension MarkdownNode {
    /// A 1-based position in the source: `line` counts from 1, `column` is the 1-based UTF-8 **byte** offset within that line (so a leading multi-byte scalar advances the column by its byte count, matching cmark's convention).
    public struct SourcePosition: Comparable, Hashable, Sendable {
        /// The 1-based line number.
        public var line: Int
        /// The 1-based UTF-8 byte offset within the line.
        public var column: Int

        /// Creates a source position.
        ///
        /// - Parameters:
        ///   - line: The 1-based line number.
        ///   - column: The 1-based UTF-8 byte offset within the line.
        public init(line: Int, column: Int) {
            self.line = line
            self.column = column
        }

        /// Returns a Boolean value that indicates whether the first position precedes the second.
        public static func < (lhs: SourcePosition, rhs: SourcePosition) -> Bool {
            (lhs.line, lhs.column) < (rhs.line, rhs.column)
        }
    }
}

extension MarkdownNode {
    /// The node's source position range, or `nil` if the document was parsed without `.sourcePosition` or this node carries no tracked position.
    ///
    /// `lowerBound` is the position of the node's first content byte. `upperBound` is the position just past its last content byte (half-open) - i.e. the column equals the last byte's 1-based column **plus one**. (cmark reports an inclusive end column; a client wanting cmark's raw number subtracts one from `upperBound.column`.)
    public var sourceRange: Range<SourcePosition>? {
        _view.sourceRange(of: _index)
    }
}
