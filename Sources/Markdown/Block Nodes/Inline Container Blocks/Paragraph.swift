/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A paragraph.
public struct Paragraph: BlockMarkup, BasicInlineContainer {
    public var _data: _MarkupData
    init(_ data: _MarkupData) {
        self._data = data
    }

    init(_ raw: RawMarkup) throws {
        guard case .paragraph = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: Paragraph.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }
}

// MARK: - Public API

public extension Paragraph {
    // MARK: InlineContainer

    init(_ newChildren: some Sequence<InlineMarkup>) {
        self.init(newChildren, inheritSourceRange: false)
    }

    init(_ newChildren: some Sequence<InlineMarkup>, inheritSourceRange: Bool) {
        let rawChildren = newChildren.map { $0.raw.markup }
        let parsedRange = inheritSourceRange ? rawChildren.parsedRange : nil
        try! self.init(.paragraph(parsedRange: parsedRange, rawChildren))
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitParagraph(self)
    }
}
