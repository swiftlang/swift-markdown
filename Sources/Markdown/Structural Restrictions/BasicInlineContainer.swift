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
    init(_ children: some Sequence<InlineMarkup>)

    /// Create this element with a sequence of inline markup elements, and optionally inherit the source range from those elements.
    init(_ children: some Sequence<InlineMarkup>, inheritSourceRange: Bool)
}

extension BasicInlineContainer {
    /// Create this element with a sequence of inline markup elements.
    public init(_ children: InlineMarkup...) {
        self.init(children)
    }

    public init(_ children: InlineMarkup..., inheritSourceRange: Bool) {
        self.init(children, inheritSourceRange: inheritSourceRange)
    }

    /// Default implementation for `init(_:inheritSourceRange:)` that discards the `inheritSourceRange` parameter.
    public init(_ children: some Sequence<InlineMarkup>, inheritSourceRange: Bool) {
        self.init(children)
    }
}
