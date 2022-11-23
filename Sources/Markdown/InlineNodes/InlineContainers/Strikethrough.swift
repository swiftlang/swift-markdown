/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// Inline elements that should be rendered with a strike through them.
public struct Strikethrough: RecurringInlineMarkup, BasicInlineContainer {
    public var _data: _MarkupData
    init(_ raw: RawMarkup) throws {
        guard case .strikethrough = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: Strikethrough.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }
    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension Strikethrough {
    // MARK: BasicInlineContainer

    init<Children>(_ newChildren: Children) where Children : Sequence, Children.Element == InlineMarkup {
        try! self.init(.strikethrough(parsedRange: nil, newChildren.map { $0.raw.markup }))
    }

    // MARK: PlainTextConvertibleMarkup

    var plainText: String {
        let childrenPlainText = children.compactMap {
            return ($0 as? InlineMarkup)?.plainText
        }.joined()
        return "~\(childrenPlainText)~"
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitStrikethrough(self)
    }
}
