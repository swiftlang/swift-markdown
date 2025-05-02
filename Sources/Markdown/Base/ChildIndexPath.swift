/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An array of indexes for traversing deeply into a markup tree.
public typealias ChildIndexPath = [Int]

/// A description of a traversal through a markup tree by index and optional expected type.
public struct TypedChildIndexPath: RandomAccessCollection, ExpressibleByArrayLiteral, Sendable {
    /// A pair consisting of an expected index and optional expected type for a child element.
    ///
    /// This type is a shorthand convenience when creating a ``TypedChildIndexPath`` from an array literal.
    public typealias ArrayLiteralElement = (Int, Markup.Type?)

    /// An element of a complex child index path.
    public struct Element: Sendable {
        /// The index to use when descending into the children.
        var index: Int

        /**
         The expected type of the child at ``index``.

         Use this to restrict the type of node to enter at this point in the traversal. If the child doesn't match this type, the traversal will fail. To allow any type of child markup type, set this to `nil`.
         */
        var expectedType: Markup.Type?
    }

    /// The elements of the path.
    private var elements: [Element]

    /// Create an empty path.
    public init() {
        elements = []
    }

    /// Create a path from a sequence of index-type pairs.
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.elements = Array(elements)
    }

    /// Create a path from a sequence of index-type pairs.
    public init(arrayLiteral elements: ArrayLiteralElement...) {
        self.elements = elements.map { Element(index: $0.0, expectedType: $0.1) }
    }

    public var startIndex: Int {
        return elements.startIndex
    }

    public var endIndex: Int {
        return elements.endIndex
    }

    public subscript(index: Int) -> Element {
        return elements[index]
    }
}
