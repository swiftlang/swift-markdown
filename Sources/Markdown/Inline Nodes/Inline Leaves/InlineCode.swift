/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An inline code markup element, representing some code-like or "code voice" text.
public struct InlineCode: RecurringInlineMarkup {
    public var _data: _MarkupData

    init(_ raw: RawMarkup) throws {
        guard case .inlineCode = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: InlineCode.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension InlineCode {
    /// Create an inline code element from a string.
    init(_ code: String) {
        try! self.init(.inlineCode(parsedRange: nil, code: code))
    }

    /// The literal text content.
    var code: String {
        get {
            guard case let .inlineCode(code) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return code
        }
        set {
            self._data = _data.replacingSelf(.inlineCode(parsedRange: nil, code: newValue))
        }
    }

    // MARK: PlainTextConvertibleMarkup

    var plainText: String {
        return "`\(code)`"
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitInlineCode(self)
    }
}
