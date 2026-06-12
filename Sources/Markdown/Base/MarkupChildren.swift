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
        let parentData: _MarkupData
        var childMetadata: MarkupMetadata

        init(_ parentData: _MarkupData) {
            self.parentData = parentData
            self.childMetadata = parentData.raw.metadata.firstChild()
        }

        public mutating func next() -> Markup? {
            let index = childMetadata.indexInParent
            guard index < parentData.raw.markup.childCount else {
                return nil
            }
            let rawChild = parentData.raw.markup.child(at: index)
            let absoluteRawChild = AbsoluteRawMarkup(markup: rawChild, metadata: childMetadata)
            let parent = makeMarkup(parentData)
            let data = _MarkupData(absoluteRawChild, parent: parent)
            childMetadata = childMetadata.nextSibling(from: rawChild)
            return makeMarkup(data)
        }
    }

    /// The data of the parent whose children this sequence represents.
    let parentData: _MarkupData

    /// Create a lazy sequence of an element's children.
    ///
    /// - parameter parent: the parent whose children this sequence represents.
    init(_ parent: Markup) {
        self.parentData = parent._data
    }

    // MARK: Sequence

    public func makeIterator() -> Iterator {
        return Iterator(parentData)
    }

    /// A reversed view of the element's children.
    public func reversed() -> ReversedMarkupChildren {
        return ReversedMarkupChildren(parentData)
    }
}

/// A sequence consisting of an element's child elements in reverse.
///
/// This is a `Sequence` and not a `Collection` because
/// information that locates a child element under a parent element is not
/// cached and calculated on demand.
public struct ReversedMarkupChildren: Sequence {
    public struct Iterator: IteratorProtocol {
        /// The data of the parent whose children this sequence represents.
        let parentData: _MarkupData

        /// The metadata to use when creating an absolute child element.
        var childMetadata: MarkupMetadata

        init(_ parentData: _MarkupData) {
            self.parentData = parentData
            self.childMetadata = parentData.raw.metadata.lastChildMetadata(of: parentData.raw.markup)
        }

        public mutating func next() -> Markup? {
            let index = childMetadata.indexInParent
            guard index >= 0 else {
                return nil
            }
            let rawChild = parentData.raw.markup.child(at: index)
            let absoluteRawChild = AbsoluteRawMarkup(markup: rawChild, metadata: childMetadata)
            let parent = makeMarkup(parentData)
            let data = _MarkupData(absoluteRawChild, parent: parent)
            childMetadata = childMetadata.previousSibling(from: rawChild)
            return makeMarkup(data)
        }
    }

    /// The data of the parent whose children this sequence represents.
    let parentData: _MarkupData

    /// Create a reversed view of an element's children.
    ///
    /// - parameter parent: The parent whose children this sequence will represent.
    init(_ parent: Markup) {
        self.parentData = parent._data
    }

    init(_ parentData: _MarkupData) {
        self.parentData = parentData
    }

    // MARK: Sequence
    public func makeIterator() -> Iterator {
        return Iterator(parentData)
    }
}
