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

/// If `markup` is an inline markup element, return its `plainText`.
/// Otherwise return `nil`.
///
/// This is the Embedded-Swift–compatible equivalent of
/// `(markup as? InlineMarkup)?.plainText`. It dispatches on the concrete
/// kind of the underlying raw markup data instead of using a dynamic cast,
/// which is unavailable in Embedded Swift.
internal func inlinePlainText(of markup: Markup) -> String? {
    switch markup._data.raw.markup.data {
    case .text:
        return Text(markup._data).plainText
    case .emphasis:
        return Emphasis(markup._data).plainText
    case .strong:
        return Strong(markup._data).plainText
    case .image:
        return Image(markup._data).plainText
    case .inlineCode:
        return InlineCode(markup._data).plainText
    case .softBreak:
        return SoftBreak(markup._data).plainText
    case .lineBreak:
        return LineBreak(markup._data).plainText
    case .inlineHTML:
        return InlineHTML(markup._data).plainText
    case .strikethrough:
        return Strikethrough(markup._data).plainText
    case .link:
        return Link(markup._data).plainText
    case .symbolLink:
        return SymbolLink(markup._data).plainText
    case .customInline:
        return CustomInline(markup._data).plainText
    case .inlineAttributes:
        return InlineAttributes(markup._data).plainText
    default:
        return nil
    }
}
