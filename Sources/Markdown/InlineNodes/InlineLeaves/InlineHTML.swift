/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An inline markup element containing raw HTML.
public struct InlineHTML: RecurringInlineMarkup, LiteralMarkup {
    public var _data: _MarkupData
    init(_ raw: RawMarkup) throws {
        guard case .inlineHTML = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: InlineHTML.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension InlineHTML {
    init(_ literalText: String) {
        try! self.init(.inlineHTML(parsedRange: nil, html: literalText))
    }

    /// The raw HTML text.
    var rawHTML: String {
        get {
            guard case let .inlineHTML(text) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return text
        }
        set {
            _data = _data.replacingSelf(.inlineHTML(parsedRange: nil, html: newValue))
        }
    }

    // MARK: PlainTextConvertibleMarkup

    var plainText: String {
        return rawHTML
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitInlineHTML(self)
    }
}
