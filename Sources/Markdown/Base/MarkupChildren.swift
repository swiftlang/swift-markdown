/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A lazy sequence consisting of an element's child elements.
///
/// This is a `Sequence` and not a `Collection` because
/// information that locates a child element under a parent element is not
/// cached and calculated on demand.
public struct MarkupChildren: Sequence {
    public struct Iterator: IteratorProtocol {
        let parent: Markup
        var childMetadata: MarkupMetadata

        init(_ parent: Markup) {
            self.parent = parent
            self.childMetadata = parent.raw.metadata.firstChild()
        }

        public mutating func next() -> Markup? {
            let index = childMetadata.indexInParent
            guard index < parent.childCount else {
                return nil
            }
            let rawChild = parent.raw.markup.child(at: index)
            let absoluteRawChild = AbsoluteRawMarkup(markup: rawChild, metadata: childMetadata)
            let data = _MarkupData(absoluteRawChild, parent: parent)
            childMetadata = childMetadata.nextSibling(from: rawChild)
            return makeMarkup(data)
        }
    }

    /// The parent whose children this sequence represents.
    let parent: Markup

    /// Create a lazy sequence of an element's children.
    ///
    /// - parameter parent: the parent whose children this sequence represents.
    init(_ parent: Markup) {
        self.parent = parent
    }

    // MARK: Sequence

    public func makeIterator() -> Iterator {
        return Iterator(parent)
    }

    /// A reversed view of the element's children.
    public func reversed() -> ReversedMarkupChildren {
        return ReversedMarkupChildren(parent)
    }
}

/// A sequence consisting of an element's child elements in reverse.
///
/// This is a `Sequence` and not a `Collection` because
/// information that locates a child element under a parent element is not
/// cached and calculated on demand.
public struct ReversedMarkupChildren: Sequence {
    public struct Iterator: IteratorProtocol {
        /// The parent whose children this sequence represents.
        ///
        /// This is also necessary for creating an "absolute" child from
        /// parentless ``RawMarkup``.
        let parent: Markup

        /// The metadata to use when creating an absolute child element.
        var childMetadata: MarkupMetadata

        init(_ parent: Markup) {
            self.parent = parent
            self.childMetadata = parent.raw.metadata.lastChildMetadata(of: parent.raw.markup)
        }

        public mutating func next() -> Markup? {
            let index = childMetadata.indexInParent
            guard index >= 0 else {
                return nil
            }
            let rawChild = parent.raw.markup.child(at: index)
            let absoluteRawChild = AbsoluteRawMarkup(markup: rawChild, metadata: childMetadata)
            let data = _MarkupData(absoluteRawChild, parent: parent)
            childMetadata = childMetadata.previousSibling(from: rawChild)
            return makeMarkup(data)
        }
    }

    /// The parent whose children this sequence represents.
    let parent: Markup

    /// Create a reversed view of an element's children.
    ///
    /// - parameter parent: The parent whose children this sequence will represent.
    init(_ parent: Markup) {
        self.parent = parent
    }

    // MARK: Sequence
    public func makeIterator() -> Iterator {
        return Iterator(parent)
    }
}
