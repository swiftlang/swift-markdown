/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// Plain text.
public struct Text: RecurringInlineMarkup, LiteralMarkup {
    public var _data: _MarkupData

    init(_ raw: RawMarkup) throws {
        guard case .text = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: Text.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension Text {
    init(_ literalText: String) {
        try! self.init(.text(parsedRange: nil, string: literalText))
    }

    /// The raw text of the element.
    var string: String {
        get {
            guard case let .text(string) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return string
        }
        set {
            _data = _data.replacingSelf(.text(parsedRange: nil, string: newValue))
        }
    }

    // MARK: PlainTextConvertibleMarkup

    var plainText: String {
        return string
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitText(self)
    }
}
