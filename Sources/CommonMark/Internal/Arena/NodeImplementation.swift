/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// Per-kind storage variant for a node.
internal enum NodeData {
    /// Inline literal content (text, code spans, raw HTML inlines) and code-block bodies.
    case literal(ContentRef)

    /// Code block content - info string (language tag) and the literal body. Fence metadata (`isFenced`, fence character/length/offset) lives on the node's `kind` as `CodeBlockInfo`.
    case codeBlock(info: ContentRef, literal: ContentRef)

    /// Link or image destination + title.
    case link(url: ContentRef, title: ContentRef)

    /// Raw HTML block - type id (1..7 per CommonMark spec) + body literal.
    case htmlBlock(type: UInt8, literal: ContentRef)

    /// `^[..]` extended attribute node (fork-specific). The ref is the raw uninterpreted attribute string (e.g. `"color: red, rainbow: 'extreme'"`).
    case attribute(ContentRef)

    /// Footnote reference - the original label (used for resolution and rendering). The assigned 1-based index lives on the node's `kind`.
    case footnoteReference(label: ContentRef)

    /// Footnote definition - original label, count of references that resolved to this definition.
    case footnoteDefinition(label: ContentRef, referenceCount: Int)

    /// Table - column count and per-column alignment table.
    case table(columnCount: Int, alignmentsOffset: Int)

    /// List item - `padding` is the column at which the item's content starts, relative to the line position where the parent list/item walk began - used by the per-line container walk to strip leading indentation on continuation lines. The tasklist checked state lives on the node's `kind`.
    case item(padding: Int)
}

/// Fixed-size record for one AST node. Stored contiguously in `DocumentStorage.nodes`.
internal struct NodeRecord {
    internal var kind: MarkdownNode.Kind
    internal var firstChild: DocumentStorage.Index?
    internal var lastChild: DocumentStorage.Index?
    internal var next: DocumentStorage.Index?
    internal var previous: DocumentStorage.Index?
    internal var parent: DocumentStorage.Index?
    internal var data: NodeData?

    /// `true` when a blank line was the most recent line processed while this node was open. Drives CommonMark tight/loose list detection (`detectLooseList` / `endsWithBlankLine`). Stored inline here rather than in a side `Set<Index>` so set/clear/test are O(1) array-field accesses with no hashing.
    internal var lastLineBlank: Bool = false

    internal init(
        kind: MarkdownNode.Kind,
        parent: DocumentStorage.Index? = nil,
        data: NodeData? = nil
    ) {
        self.kind = kind
        self.firstChild = nil
        self.lastChild = nil
        self.next = nil
        self.previous = nil
        self.parent = parent
        self.data = data
    }
}
