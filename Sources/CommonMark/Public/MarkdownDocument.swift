/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A parsed Markdown document.
///
/// A document borrows the UTF-8 bytes of its source instead of copying them, so its lifetime is bounded by that borrow and the source must outlive it. Because a document can't escape its borrow scope, the entry point that works on every OS release is `withParsedDocument(_:options:_:)`, which passes the borrowed document to a closure. Where `UTF8Span` is available, `init(parsing:options:)` returns a document whose lifetime is tied to the source instead.
///
///     let source = "# Hello\n\nworld"
///     try MarkdownDocument.withParsedDocument(source) { document in
///         document.root.children.forEach { print($0.kind) }
///     }
public struct MarkdownDocument: ~Copyable, ~Escapable {

    internal var _storage: DocumentStorage

    internal let _source: Span<UInt8>

    /// Core parser entry: borrow the source bytes and parse. Internal - `Span<UInt8>` is not public API (the public surface only accepts `String` / `UTF8Span`, guaranteeing validated Unicode input).
    @_lifetime(copy source)
    internal init(parsing source: Span<UInt8>, options: MarkdownDocument.ParseOptions = []) throws(Error) {
        let storage = DocumentStorage(options: options)
        let parser = BlockParser(storage: storage, source: source)
        self._storage = try parser.parse()
        self._source = source
    }

    /// Creates a document by parsing UTF-8 text.
    ///
    /// The document borrows `source`'s bytes instead of copying them, so its lifetime is tied to `source`.
    ///
    /// - Parameters:
    ///   - source: The Markdown text to parse.
    ///   - options: The options that control parsing.
    /// - Throws: An `Error` if parsing exceeds an internal limit.
    @available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
    @_lifetime(copy source)
    public init(parsing source: UTF8Span, options: MarkdownDocument.ParseOptions = []) throws(Error) {
        try self.init(parsing: source.span, options: options)
    }

    /// Parses a string as Markdown and passes the borrowed document to a closure.
    ///
    /// Use this method to parse on any supported OS release. The document borrows the string's UTF-8 bytes for the duration of `body`, so neither the document nor any `MarkdownNode` obtained from it can escape the closure.
    ///
    /// - Parameters:
    ///   - source: The Markdown text to parse.
    ///   - options: The options that control parsing.
    ///   - body: A closure that receives the borrowed document, valid only for the duration of the call.
    /// - Returns: The value returned by `body`.
    /// - Throws: An `Error` if parsing exceeds an internal limit, or any error `body` throws.
    public static func withParsedDocument<R>(
        _ source: borrowing String,
        options: MarkdownDocument.ParseOptions = [],
        _ body: (borrowing MarkdownDocument) throws -> R
    ) throws -> R {
        if #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) {
            let utf8 = source.utf8Span
            let document = try MarkdownDocument(parsing: utf8, options: options)
            return try body(document)
        }
        // Pre-26 fallback: borrow the contiguous UTF-8 (makeContiguousUTF8 normalizes, copying only a non-contiguous string).
        var contiguous = copy source
        contiguous.makeContiguousUTF8()
        if let result = try contiguous.utf8.withContiguousStorageIfAvailable({ (buffer: UnsafeBufferPointer<UInt8>) throws -> R in
            let document = try MarkdownDocument(parsing: Span(_unsafeElements: buffer), options: options)
            return try body(document)
        }) {
            return result
        }
        // Empty input has no contiguous storage; parse an empty document.
        let empty = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
        let document = try MarkdownDocument(parsing: Span(_unsafeElements: empty), options: options)
        return try body(document)
    }

    /// The root node of the document's syntax tree.
    ///
    /// Its kind is always `.document`.
    public var root: MarkdownNode {
        @_lifetime(borrow self)
        borrowing get {
            let view = StorageView(storage: _storage, source: _source)
            return MarkdownNode(view: view, index: DocumentStorage.Index(0))
        }
    }

    /// The options the document was parsed with.
    public var options: MarkdownDocument.ParseOptions {
        borrowing get { _storage.options }
    }

    /// The source text the document was parsed from.
    @available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
    public var source: UTF8Span {
        @_lifetime(borrow self)
        borrowing get {
            // The source is already known-valid UTF-8 - it came from a validated `String` or `UTF8Span` at construction - so skip re-validation with the unchecked initializer.
            unsafe UTF8Span(unchecked: _source)
        }
    }

    /// The number of lines in the document.
    public var lineCount: Int {
        _storage.lineCount
    }

    /// The size in bytes of the materialized string buffer, for debugging and optimization.
    public var _materializedStringSize: Int {
        _storage.strings.count
    }

    /// The number of content segments in the storage pool, for debugging and optimization.
    public var _segmentCount: Int {
        _storage.segments.count
    }

    /// An error thrown while parsing a `MarkdownDocument`.
    public enum Error : Swift.Error {
        /// The parser exceeded an internal limit, such as the maximum allowed recursion depth.
        case parsingLimitExceeded
    }
}

extension MarkdownDocument {
    /// Creates a document by parsing a string as Markdown.
    ///
    /// The document borrows the string's UTF-8 bytes instead of copying them, so its lifetime is tied to `source`. To parse on an OS release that doesn't provide `UTF8Span`, use `withParsedDocument(_:options:_:)` instead.
    ///
    /// - Parameters:
    ///   - source: The Markdown text to parse.
    ///   - options: The options that control parsing.
    /// - Throws: An `Error` if parsing exceeds an internal limit.
    @available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
    @_lifetime(borrow source)
    public init(parsing source: borrowing String, options: MarkdownDocument.ParseOptions = []) throws(Error) {
        try self.init(parsing: source.utf8Span, options: options)
    }
}
