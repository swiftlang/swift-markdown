/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension MarkdownNode {

    /// A node's content, exposed as borrowed spans you inspect with a single `switch`.
    ///
    /// Because the cases carry spans that point into the document's storage, a `Content` value can't escape the node's borrow scope or be stored - read it in place. For an owned `String` form that you can store, and that reads content on any OS release, use `stringContent`.
    ///
    /// Textual content is always a `Segments` sequence. Inline literals are usually a single segment, but code- and HTML-block bodies can span several - their lines are stored non-contiguously - so iterate the segments rather than assuming one contiguous span.
    @available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
    public enum Content: ~Copyable, ~Escapable {
        /// No content (structural nodes: document, list, item, table, breaks, emphasis, …).
        case none
        /// Inline literal text - `.text`, `.codeInline`, `.htmlInline`.
        case text(Segments)
        /// A code block: the info-string span plus the (possibly multi-line) body as segments.
        case codeBlock(info: UTF8Span, body: Segments)
        /// An HTML block body as segments.
        case htmlBlock(body: Segments)
        /// A link or image: destination URL and title spans (either may be empty).
        case link(url: UTF8Span, title: UTF8Span)
        /// An `^[…]` extended-attribute raw string.
        case attribute(UTF8Span)
        /// A footnote reference or definition label.
        case footnote(label: UTF8Span)
    }

    /// The node's content as borrowed spans, the companion to `kind`.
    ///
    /// For an owned `String` form, or to read content on an OS release without `UTF8Span`, use `stringContent`.
    @available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
    public var content: Content {
        @_lifetime(borrow self)
        get {
            switch _view.record(at: _index).data {
            case .literal(let ref):
                return .text(Segments(view: _view, ref: ref))
            case .codeBlock(let info, let body):
                return .codeBlock(info: _view.utf8Span(of: info), body: Segments(view: _view, ref: body))
            case .htmlBlock(_, let body):
                return .htmlBlock(body: Segments(view: _view, ref: body))
            case .link(let url, let title):
                return .link(url: _view.utf8Span(of: url), title: _view.utf8Span(of: title))
            case .attribute(let ref):
                return .attribute(_view.utf8Span(of: ref))
            case .footnoteReference(let label):
                return .footnote(label: _view.utf8Span(of: label))
            case .footnoteDefinition(let label, _):
                return .footnote(label: _view.utf8Span(of: label))
            default:
                return .none
            }
        }
    }
}

extension MarkdownNode {

    /// A node's content as owned `String` values, the companion to `kind`.
    ///
    /// Unlike `Content`, these values are `Copyable` and `Escapable`, so you can store them and let them outlive the node. Where `UTF8Span` is available, `content` provides the same information as borrowed spans, without copying.
    public enum StringContent: Sendable, Hashable {
        /// No content (structural nodes: document, list, item, table, breaks, emphasis, …).
        case none
        /// Inline literal text - `.text`, `.codeInline`, `.htmlInline`.
        case text(String)
        /// A code block: the info string (language tag) plus the body.
        case codeBlock(info: String, body: String)
        /// An HTML block body.
        case htmlBlock(body: String)
        /// A link or image: destination URL and title (either may be empty).
        case link(url: String, title: String)
        /// An `^[…]` extended-attribute raw string.
        case attribute(String)
        /// A footnote reference or definition label.
        case footnote(label: String)
    }

    /// The node's content as owned `String` values.
    ///
    /// For a borrowed, non-copying form where `UTF8Span` is available, use `content`.
    public var stringContent: StringContent {
        borrowing get {
            switch _view.record(at: _index).data {
            case .literal(let ref):
                return .text(_view.string(of: ref))
            case .codeBlock(let info, let body):
                return .codeBlock(info: _view.string(of: info), body: _view.string(of: body))
            case .htmlBlock(_, let body):
                return .htmlBlock(body: _view.string(of: body))
            case .link(let url, let title):
                return .link(url: _view.string(of: url), title: _view.string(of: title))
            case .attribute(let ref):
                return .attribute(_view.string(of: ref))
            case .footnoteReference(let label):
                return .footnote(label: _view.string(of: label))
            case .footnoteDefinition(let label, _):
                return .footnote(label: _view.string(of: label))
            default:
                return .none
            }
        }
    }
}
