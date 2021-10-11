/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A unique identifier for an element in any markup tree currently in memory.
struct MarkupIdentifier: Equatable {
    /// A globally unique identifier for the root of the tree,
    /// acting as a scope for child identifiers.
    let rootId: UInt64

    /// A locally unique identifier for a child under a root.
    let childId: Int

    /// Returns the identifier for the first child of this identifier's element.
    func firstChild() -> MarkupIdentifier {
        return .init(rootId: rootId, childId: childId + 1)
    }

    /// Returns the identifier for the next sibling of the given raw element.
    ///
    /// - Note: This method assumes that this identifier belongs to `raw`.
    func nextSibling(from raw: RawMarkup) -> MarkupIdentifier {
        return .init(rootId: rootId, childId: childId + raw.subtreeCount)
    }

    /// Returns the identifier for the previous sibling of the given raw element.
    ///
    /// - Note: This method assumes that this identifier belongs to `raw`.
    func previousSibling(from raw: RawMarkup) -> MarkupIdentifier {
        return .init(rootId: rootId, childId: childId - raw.subtreeCount)
    }

    /// Returns the identifier for the last child of this identifier's element.
    func lastChildOfParent(_ parent: RawMarkup) -> MarkupIdentifier {
        return .init(rootId: rootId, childId: childId + parent.subtreeCount)
    }

    /// Returns an identifier for a new root element.
    static func newRoot() -> MarkupIdentifier {
        return .init(rootId: AtomicCounter.next(), childId: 0)
    }
}

/// Metadata for a specific markup element in memory.
struct MarkupMetadata {
    /// A unique identifier under a root element.
    let id: MarkupIdentifier

    /// The index in the parent's children.
    let indexInParent: Int

    init(id: MarkupIdentifier, indexInParent: Int) {
        self.id = id
        self.indexInParent = indexInParent
    }

    /// Returns metadata for the first child of this metadata's element.
    func firstChild() -> MarkupMetadata {
        return MarkupMetadata(id: id.firstChild(), indexInParent: 0)
    }

    /// Returns metadata for the next sibling of the given raw element.
    ///
    /// - Note: This method assumes that this metadata belongs to `raw`.
    func nextSibling(from raw: RawMarkup) -> MarkupMetadata {
        return MarkupMetadata(id: id.nextSibling(from: raw), indexInParent: indexInParent + 1)
    }

    /// Returns metadata for the previous sibling of the given raw element.
    ///
    /// - Note: This method assumes that this metadata belongs to `raw`.
    func previousSibling(from raw: RawMarkup) -> MarkupMetadata {
        return MarkupMetadata(id: id.previousSibling(from: raw), indexInParent: indexInParent - 1)
    }

    /// Returns metadata for the last child of this identifier's element.
    ///
    /// - Note: This method assumes that this metadata belongs to `parent`.
    func lastChildMetadata(of parent: RawMarkup) -> MarkupMetadata {
        return MarkupMetadata(id: id.lastChildOfParent(parent), indexInParent: parent.childCount - 1)
    }
}

/// A specific occurrence of a reusable `RawMarkup` element in a markup tree.
///
/// Since `RawMarkup` nodes can be reused in different trees, there needs to be a way
/// to tell the difference between a paragraph that occurs in one document and
/// that same paragraph reused in another document.
///
/// This bundles a `RawMarkup` node with some metadata that keeps track of
/// where and in which tree the element resides.
struct AbsoluteRawMarkup {
    /// The relative, sharable raw markup element.
    let markup: RawMarkup

    /// Metadata associated with this particular occurrence of the raw markup.
    let metadata: MarkupMetadata
}

/// Internal data for a markup element.
///
/// Unlike `RawMarkup`, this represents a specific element of markup in a specific tree,
/// allowing mechanisms such as finding an element's parent, siblings, and order in which
/// it occurred among its siblings.
/// > Warning: This type is an implementation detail and is not meant to be used directly.
public struct _MarkupData {
    /// The `AbsoluteRawMarkup` backing this element's data.
    let raw: AbsoluteRawMarkup

    /// This element's parent, or `nil` if this is a root.
    let parent: Markup?

    /// The index of the element in its parent if it has one, else `0`.
    var indexInParent: Int {
        return raw.metadata.indexInParent
    }

    /// A unique identifier for this data. Use as you would pointer identity.
    var id: MarkupIdentifier {
        return raw.metadata.id
    }

    /// The root of the tree in which the element resides.
    var root: _MarkupData {
        guard let parent = parent else {
            return self
        }
        return parent._data.root
    }

    /// The source range of the element if it was parsed from text; otherwise, nil.
    var range: SourceRange? {
        return raw.markup.parsedRange
    }

    // Keep the `init` internal as this type is not meant to be initialized outside the framework.

    /// Creates a `MarkupData` from the given `RawMarkup` and place in an immuatable markup tree, explicitly specifying a unique identifier.
    ///
    /// - precondition: `uniqueIdentifier <= AtomicCounter.current`.
    ///
    /// - parameter raw: The `AbsoluteRawMarkup` representing the element.
    /// - parameter parent: This element's parent, `nil` if the element is a root.
    init(_ raw: AbsoluteRawMarkup, parent: Markup? = nil) {
        self.raw = raw
        self.parent = parent
    }

    /// Returns the replaced element in a new tree.
    func replacingSelf(_ newRaw: RawMarkup) -> _MarkupData {
        if let parent = parent {
            let newParent = parent._data.substitutingChild(newRaw, at: indexInParent)
            return newParent.child(at: indexInParent)!._data
        } else {
            return _MarkupData(AbsoluteRawMarkup(markup: newRaw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0)), parent: nil)
        }
    }

    /// Returns a new `MarkupData` with the given child now at the `index`.
    func substitutingChild(_ rawChild: RawMarkup, at index: Int) -> Markup {
        let newRaw = raw.markup.substitutingChild(rawChild, at: index)
        return makeMarkup(replacingSelf(newRaw))
    }
}
