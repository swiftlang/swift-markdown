/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A block element that can contain only other block elements and doesn't require any other information.
public protocol BasicBlockContainer: BlockContainer {
    /// Create this element from a sequence of block markup elements.
    init<Children: Sequence>(_ children: Children) where Children.Element == BlockMarkup
}

// MARK: - Public API

extension BasicBlockContainer {
    /// Create this element with a sequence of block markup elements.
    public init(_ children: BlockMarkup...) {
        self.init(children)
    }
}
