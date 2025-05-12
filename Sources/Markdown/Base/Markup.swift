/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// Creates an element of a type that corresponds to the kind of markup data and casts back up to `Markup`.
func makeMarkup(_ data: _MarkupData) -> Markup {
    switch data.raw.markup.data {
    case .blockQuote:
        return BlockQuote(data)
    case .codeBlock:
        return CodeBlock(data)
    case .customBlock:
        return CustomBlock(data)
    case .document:
        return Document(data)
    case .heading:
        return Heading(data)
    case .thematicBreak:
        return ThematicBreak(data)
    case .htmlBlock:
        return HTMLBlock(data)
    case .listItem:
        return ListItem(data)
    case .orderedList:
        return OrderedList(data)
    case .unorderedList:
        return UnorderedList(data)
    case .paragraph:
        return Paragraph(data)
    case .blockDirective:
        return BlockDirective(data)
    case .inlineCode:
        return InlineCode(data)
    case .customInline:
        return CustomInline(data)
    case .emphasis:
        return Emphasis(data)
    case .image:
        return Image(data)
    case .inlineHTML:
        return InlineHTML(data)
    case .lineBreak:
        return LineBreak(data)
    case .link:
        return Link(data)
    case .softBreak:
        return SoftBreak(data)
    case .strong:
        return Strong(data)
    case .text:
        return Text(data)
    case .strikethrough:
        return Strikethrough(data)
    case .table:
        return Table(data)
    case .tableRow:
        return Table.Row(data)
    case .tableHead:
        return Table.Head(data)
    case .tableBody:
        return Table.Body(data)
    case .tableCell:
        return Table.Cell(data)
    case .symbolLink:
        return SymbolLink(data)
    case .inlineAttributes:
        return InlineAttributes(data)
    case .doxygenDiscussion:
        return DoxygenDiscussion(data)
    case .doxygenNote:
        return DoxygenNote(data)
    case .doxygenAbstract:
        return DoxygenAbstract(data)
    case .doxygenParam:
        return DoxygenParameter(data)
    case .doxygenReturns:
        return DoxygenReturns(data)
    }
}

/// A markup element.
///
/// > Note: All supported markup elements are already implemented in the framework.
/// Use this protocol only as a generic constraint.
public protocol Markup {
    /// Accept a `MarkupVisitor` and call the specific visitation method for this element.
    ///
    /// - parameter visitor: The `MarkupVisitor` visiting the element.
    /// - returns: The result of the visit.
    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result

    /// The data backing the markup element.
    /// > Note: This property is an implementation detail; do not use it directly.
    var _data: _MarkupData { get set }
}

// MARK: - Private API

extension Markup {
    /// The raw markup backing the element.
    var raw: AbsoluteRawMarkup {
        return _data.raw
    }

    /// The total number of nodes in the subtree rooted at this element, including this one.
    ///
    /// For example:
    /// ```
    /// Document
    /// └─ Paragraph
    ///    ├─ Text "Just a "
    ///    ├─ Emphasis
    ///    │  └─ Text "sentence"
    ///    └─ Text "."
    /// ```
    ///
    /// - Complexity: `O(1)`
    var subtreeCount: Int {
        return raw.markup.header.subtreeCount
    }

    /// Return this element without ``SoftBreak`` elements, or `nil` if this
    /// is a ``SoftBreak`` element.
    var withoutSoftBreaks: Self? {
        var softBreakDeleter = SoftBreakDeleter()
        return softBreakDeleter.visit(self) as? Self
    }

    /// Returns a copy of this element with the given children instead.
    ///
    /// - parameter newChildren: A sequence of children to use instead of the current children.
    /// - warning: This does not check for compatibility. This API should only be used when the type of the children are already known to be the right kind.
    public func withUncheckedChildren<Children: Sequence>(_ newChildren: Children) -> Markup where Children.Element == Markup {
        let newRaw = raw.markup.withChildren(newChildren.map { $0.raw.markup })
        return makeMarkup(_data.replacingSelf(newRaw))
    }
}

// MARK: - Public API

extension Markup {
    /// The text range where this element was parsed, or `nil` if it was constructed outside of parsing.
    ///
    /// - Complexity: `O(height)` (The root element holds range information for its subtree)
    public var range: SourceRange? {
        return _data.range
    }

    /// The root of the tree in which this element resides, or the element itself if it is the root.
    ///
    /// - Complexity: `O(height)`
    public var root: Markup {
        return makeMarkup(_data.root)
    }

    /// The parent of this element, or `nil` if this is a root.
    public var parent: Markup? {
        return _data.parent
    }

    /// Returns this element detached from its parent.
    public var detachedFromParent: Markup {
        guard _data.id.childId != 0 else {
            // This is already a root.
            return self
        }
        let newRaw = AbsoluteRawMarkup(markup: raw.markup, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        return makeMarkup(_MarkupData(newRaw, parent: nil))
    }

    /// The number of this element's children.
    ///
    /// - Complexity: `O(1)`
    public var childCount: Int {
        return raw.markup.header.childCount
    }

    /// `true` if this element has no children.
    ///
    /// - Complexity: `O(1)`
    public var isEmpty: Bool {
        return childCount == 0
    }

    /// The children of the element.
    public var children: MarkupChildren {
        return MarkupChildren(self)
    }

    /// Returns the child at the given position if it is within the bounds of `children.indices`.
    ///
    /// - Complexity: `O(childCount)`
    public func child(at position: Int) -> Markup? {
        precondition(position >= 0, "Cannot retrieve a child at negative index: \(position)")
        guard position < raw.markup.childCount else {
            return nil
        }
        
        let childMetadata: MarkupMetadata
        if position == 0 {
            childMetadata = raw.metadata.firstChild()
        } else {
            let siblingSubtreeCount = (0..<position).reduce(0) { partialSubtreeCount, currentPosition in
                return partialSubtreeCount + raw.markup.child(at: currentPosition).subtreeCount
            }
            
            let firstChildID = raw.metadata.firstChild().id
            let childID = MarkupIdentifier(
                rootId: firstChildID.rootId,
                childId: firstChildID.childId + siblingSubtreeCount
            )
            
            childMetadata = MarkupMetadata(id: childID, indexInParent: position)
        }
        
        let rawChild = raw.markup.child(at: position)
        let absoluteRawMarkup = AbsoluteRawMarkup(markup: rawChild, metadata: childMetadata)
        let data = _MarkupData(absoluteRawMarkup, parent: self)
        return makeMarkup(data)
    }

    /// Traverse this markup tree by descending into the child at the index of each path element, returning `nil` if there is no child at that index or if the expected type for that path element doesn't match.
    ///
    /// For example, given the following tree:
    /// ```
    /// Document
    ///  └─ Paragraph
    ///    ├─ Text "This is "
    ///    ├─ Emphasis
    ///    │  └─ Text "emphasized"
    ///    └─ Text "."
    /// ```
    ///
    /// To get the `Text "emphasized"` element, you could provide the following path:
    ///
    /// ```swift
    /// [
    ///   (0, Paragraph.self), // Document's child 0, a Paragraph element
    ///   (1, Emphasis.self),  // Paragraph's child 1, an Emphasis element
    ///   (0, Text.self),      // Emphasis's child 0, the `Text "emphasized"` element.
    /// ]
    /// ```
    ///
    /// Using a `TypedChildIndexPath` without any expected types:
    /// ```swift
    /// [
    ///   (0, nil),
    ///   (1, nil),
    ///   (0, nil),
    /// ]
    /// ```
    /// would also provide a match.
    ///
    /// An example of a path that wouldn't match the `Text "emphasized"` element would be:
    ///
    /// ```swift
    /// [
    ///   (0, Paragraph.self),
    ///   // The search would fail here because this element
    ///   // isn't `Strong` but `Emphasized`.
    ///   (1, Strong.self),
    ///   (0, Text.self),
    /// ]
    /// ```
    public func child(through path: TypedChildIndexPath) -> Markup? {
        var element: Markup = self
        for pathElement in path {
            guard pathElement.index <= element.childCount else {
                return nil
            }

            guard let childElement = element.child(at: pathElement.index) else {
                return nil
            }
            
            element = childElement

            guard let expectedType = pathElement.expectedType else {
                continue
            }
            guard type(of: element) == expectedType else {
                return nil
            }
        }
        return element
    }

    /// Traverse this markup tree by descending into the child at the index of each path element, returning `nil` if there is no child at that index.
    ///
    /// For example, given the following tree:
    /// ```
    /// Document
    ///  └─ Paragraph
    ///    ├─ Text "This is "
    ///    ├─ Emphasis
    ///    │  └─ Text "emphasized"
    ///    └─ Text "."
    /// ```
    ///
    /// To get the `Text "emphasized"` element, you would provide the following path:
    ///
    /// ```swift
    /// [
    ///   0, // Document's child 0, a Paragraph element
    ///   1, // Paragraph's child 1, an Emphasis element
    ///   0, // Emphasis's child 0, the `Text "emphasized"` element.
    /// ]
    /// ```
    ///
    /// This would be equivalent to using the `TypedChildIndexPath` without any expected types:
    /// ```swift
    /// [
    ///   (0, nil),
    ///   (1, nil),
    ///   (0, nil),
    /// ]
    /// ```
    public func child<S: Sequence>(through path: S) -> Markup? where S.Element == Int {
        let pathElements = path.map { TypedChildIndexPath.Element(index: $0, expectedType: nil)}
        return child(through: TypedChildIndexPath(pathElements))
    }

    /// Traverse this markup tree by descending into the child at the index of each path element, returning `nil` if there is no child at that index.
    ///
    /// For example, given the following tree:
    /// ```
    /// Document
    ///  └─ Paragraph
    ///    ├─ Text "This is "
    ///    ├─ Emphasis
    ///    │  └─ Text "emphasized"
    ///    └─ Text "."
    /// ```
    ///
    /// To get the `Text "emphasized"` element, you would provide the following path:
    ///
    /// ```swift
    /// [
    ///   0, // Document's child 0, a Paragraph element
    ///   1, // Paragraph's child 1, an Emphasis element
    ///   0, // Emphasis's child 0, the `Text "emphasized"` element.
    /// ]
    /// ```
    ///
    /// This would be equivalent to using the `TypedChildIndexPath` without any expected types:
    /// ```swift
    /// [
    ///   (0, nil),
    ///   (1, nil),
    ///   (0, nil),
    /// ]
    /// ```
    public func child(through path: ChildIndexPath.Element...) -> Markup? {
        return child(through: path)
    }

    /// The index in the parent's children.
    public var indexInParent: Int {
        return _data.indexInParent
    }

    /// Returns `true` if this element is identical to another, comparing internal unique identifiers.
    ///
    /// - Note: Use this to bypass checking for structural equality.
    /// - Complexity: `O(1)`
    public func isIdentical(to other: Markup) -> Bool {
        return self._data.id == other._data.id
    }

    /// Returns true if this element has the same tree structure underneath it as another element.
    ///
    /// - Complexity: `O(subtreeCount)`
    public func hasSameStructure(as other: Markup) -> Bool {
        return self.raw.markup.hasSameStructure(as: other.raw.markup)
    }

    /// Print this element with the given formatting rules.
    public func format(options: MarkupFormatter.Options = .default) -> String {
        let elementToFormat: Markup

        if options.preferredLineLimit != nil {
            // If there is a preferred line limit, first remove
            // all existing soft breaks, unwrapping all lines to their
            // maximum length.
            guard let withoutSoftBreaks = self.withoutSoftBreaks else {
                return ""
            }
            elementToFormat = withoutSoftBreaks
        } else {
            elementToFormat = self
        }

        var formatter = MarkupFormatter(formattingOptions: options)
        formatter.visit(elementToFormat)
        return formatter.result
    }
}

/// Replaces soft break elements with a single space.
fileprivate struct SoftBreakDeleter: MarkupRewriter {
    func visitSoftBreak(_ softBreak: SoftBreak) -> Markup? {
        return Text(" ")
    }
}

