/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A block element whose children must conform to `BlockMarkup`
public protocol BlockContainer: BlockMarkup {}

// MARK: - Public API

public extension BlockContainer {
    /// The inline child elements of this element.
    ///
    /// - Precondition: All children of an `InlineContainer`
    ///   must conform to `InlineMarkup`.
    var blockChildren: LazyMapSequence<MarkupChildren, BlockMarkup> {
        return children.lazy.map { $0 as! BlockMarkup }
    }

    /// Replace all inline child elements with a new sequence of inline elements.
    mutating func setBlockChildren<Items: Sequence>(_ newChildren: Items) where Items.Element == BlockMarkup {
        replaceChildrenInRange(0..<childCount, with: newChildren)
    }

    /// Replace child inline elements in a range with a new sequence of elements.
    mutating func replaceChildrenInRange<Items: Sequence>(_ range: Range<Int>, with incomingItems: Items) where Items.Element == BlockMarkup {
        var rawChildren = raw.markup.copyChildren()
        rawChildren.replaceSubrange(range, with: incomingItems.map { $0.raw.markup })
        let newRaw = raw.markup.withChildren(rawChildren)
        _data = _data.replacingSelf(newRaw)
    }
}
