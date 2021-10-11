/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An element that is represented with just some plain text.
public protocol LiteralMarkup: Markup {
    /// Create an element from its literal text.
    init(_ literalText: String)
}
