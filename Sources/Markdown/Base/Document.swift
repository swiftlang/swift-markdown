/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A markup element representing the top level of a whole document.
///
/// - note: Although this could be considered a block element that can contain block elements, a `Document` itself can't be the child of any other markup, so it is not considered a block element.
public struct Document: Markup, BasicBlockContainer {
    public var _data: _MarkupData

    init(_ raw: RawMarkup) throws {
        guard case .document = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: Document.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))

    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension Document {
    // MARK: Primitive

    /// Parse a string into a `Document`.
    ///
    /// - parameter string: the input Markdown text to parse.
    /// - parameter options: options for parsing Markdown text, including
    ///   Commonmark-specific options and extensions.
    /// - parameter source: an explicit source URL from which the input `string` came for marking source locations.
    ///   This need not be a file URL.
    init(parsing string: String, source: URL? = nil, convertOptions options: ConvertOptions) {
        if options.parseOptions.contains(.parseBlockDirectives) {
            self = BlockDirectiveParser.parse(string, source: source,
                                              options: options)
        } else {
            self = MarkupParser.parseString(string, source: source, options: options)
        }
    }

    /// Parse a string into a `Document`.
    ///
    /// - parameter string: the input Markdown text to parse.
    /// - parameter options: options for parsing Markdown text.
    /// - parameter source: an explicit source URL from which the input `string` came for marking source locations.
    ///   This need not be a file URL.
    init(parsing string: String, source: URL? = nil, options: ParseOptions = []) {
        self.init(parsing: string, source: source, convertOptions: .init(fromParseOptions: options))
    }

    /// Parse a file's contents into a `Document`.
    ///
    /// - parameter file: a file URL from which to load Markdown text to parse.
    /// - parameter options: options for parsing Markdown text, including
    ///   Commonmark-specific options and extensions.
    init(parsing file: URL, convertOptions options: ConvertOptions) throws {
        let string = try String(contentsOf: file)
        if options.parseOptions.contains(.parseBlockDirectives) {
            self = BlockDirectiveParser.parse(string, source: file,
                                              options: options)
        } else {
            self = MarkupParser.parseString(string, source: file, options: options)
        }
    }

    /// Parse a file's contents into a `Document`.
    ///
    /// - parameter file: a file URL from which to load Markdown text to parse.
    /// - parameter options: options for parsing Markdown text.
    init(parsing file: URL, options: ParseOptions = []) throws {
        try self.init(parsing: file, convertOptions: .init(fromParseOptions: options))
    }

    /// Create a document from a sequence of block markup elements.
    init<Children: Sequence>(_ children: Children) where Children.Element == BlockMarkup {
        try! self.init(.document(parsedRange: nil, children.map { $0.raw.markup }))
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitDocument(self)
    }
}
