/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An element that can be converted to plain text without formatting.
public protocol PlainTextConvertibleMarkup: Markup {
    /// The plain text content of an element.
    var plainText: String { get }
}
