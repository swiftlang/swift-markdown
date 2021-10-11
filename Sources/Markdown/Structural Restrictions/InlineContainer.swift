/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An element whose children must conform to `InlineMarkup`
public protocol InlineContainer: PlainTextConvertibleMarkup {}

// MARK: - Public API

public extension InlineContainer {
    /// The inline child elements of this element.
    ///
    /// - Precondition: All children of an `InlineContainer`
    ///   must conform to `InlineMarkup`.
    var inlineChildren: LazyMapSequence<MarkupChildren, InlineMarkup> {
        return children.lazy.map { $0 as! InlineMarkup }
    }

    /// Replace all inline child elements with a new sequence of inline elements.
    mutating func setInlineChildren<Items: Sequence>(_ newChildren: Items) where Items.Element == InlineMarkup {
        replaceChildrenInRange(0..<childCount, with: newChildren)
    }

    /// Replace child inline elements in a range with a new sequence of elements.
    mutating func replaceChildrenInRange<Items: Sequence>(_ range: Range<Int>, with incomingItems: Items) where Items.Element == InlineMarkup {
        var rawChildren = raw.markup.copyChildren()
        rawChildren.replaceSubrange(range, with: incomingItems.map { $0.raw.markup })
        let newRaw = raw.markup.withChildren(rawChildren)
        _data = _data.replacingSelf(newRaw)
    }

    // MARK: PlainTextConvertibleMarkup

    var plainText: String {
        return children.compactMap {
            return ($0 as? InlineMarkup)?.plainText
        }.joined()
    }
}
