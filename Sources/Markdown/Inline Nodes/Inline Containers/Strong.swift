/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An element that tags inline elements with strong emphasis.
public struct Strong: RecurringInlineMarkup, BasicInlineContainer {
    public var _data: _MarkupData
    init(_ raw: RawMarkup) throws {
        guard case .strong = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: Strong.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }
    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension Strong {
    // MARK: BasicInlineContainer

    init(_ newChildren: some Sequence<InlineMarkup>) {
        self.init(newChildren, inheritSourceRange: false)
    }

    init(_ newChildren: some Sequence<InlineMarkup>, inheritSourceRange: Bool) {
        let rawChildren = newChildren.map { $0.raw.markup }
        let parsedRange = inheritSourceRange ? rawChildren.parsedRange : nil
        try! self.init(.strong(parsedRange: parsedRange, rawChildren))
    }

    // MARK: PlainTextConvertibleMarkup

    var plainText: String {
        let childrenPlainText = children.compactMap {
            return ($0 as? InlineMarkup)?.plainText
        }.joined()
        return "\(childrenPlainText)"
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitStrong(self)
    }
}
