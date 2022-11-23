/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A custom inline markup element.
///
/// - note: This element does not yet allow for custom information to be appended and is included for backward compatibility with CommonMark. It wraps raw text.
public struct CustomInline: RecurringInlineMarkup {
    public var _data: _MarkupData
    init(_ raw: RawMarkup) throws {
        guard case .customInline = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: CustomInline.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }
    
    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension CustomInline {
    /// Create a custom inline element from raw text.
    init(_ text: String) {
        try! self.init(.customInline(parsedRange: nil, text: text))
    }

    /// The raw inline text of the element.
    var text: String {
        guard case let .customInline(text) = _data.raw.markup.data else {
            fatalError("\(self) markup wrapped unexpected \(_data.raw)")
        }
        return text
    }

    // MARK: PlainTextConvertibleMarkup

    var plainText: String {
        return text
    }

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitCustomInline(self)
    }
}
