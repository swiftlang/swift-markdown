/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A block element containing raw HTML.
public struct HTMLBlock: BlockMarkup, LiteralMarkup {
    public var _data: _MarkupData
    init(_ raw: RawMarkup) throws {
        guard case .htmlBlock = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: HTMLBlock.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension HTMLBlock {
    init(_ literalText: String) {
        try! self.init(.htmlBlock(parsedRange: nil, html: literalText))
    }

    /// The raw HTML text comprising the block.
    var rawHTML: String {
        get {
            guard case let .htmlBlock(text) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return text
        }
        set {
            _data = _data.replacingSelf(.htmlBlock(parsedRange: nil, html: newValue))
        }
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitHTMLBlock(self)
    }
}
