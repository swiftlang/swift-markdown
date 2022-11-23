/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An inline markup element.
public protocol InlineMarkup: PlainTextConvertibleMarkup {}

/// An inline element that can recur throughout any structure.
///
/// This is mostly used to prevent some kinds of elements from nesting; for
/// example, you cannot put a ``Link`` inside another ``Link`` or an ``Image``
/// inside another ``Image``.
public protocol RecurringInlineMarkup: InlineMarkup {}
