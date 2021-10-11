/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A block or inline markup element that can contain only `InlineMarkup` elements and doesn't require any other information.
public protocol BasicInlineContainer: InlineContainer {
    /// Create this element with a sequence of inline markup elements.
    init<Children: Sequence>(_ children: Children) where Children.Element == InlineMarkup 
}

extension BasicInlineContainer {
    /// Create this element with a sequence of inline markup elements.
    public init(_ children: InlineMarkup...) {
        self.init(children)
    }
}
