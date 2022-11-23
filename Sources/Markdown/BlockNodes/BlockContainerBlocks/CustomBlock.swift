/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A custom block markup element.
///
/// - note: This element does not yet allow for custom information to be appended and is included for backward compatibility with CommonMark. It wraps any block element.
public struct CustomBlock: BlockMarkup, BasicBlockContainer {
    public var _data: _MarkupData
    init(_ raw: RawMarkup) throws {
        guard case .customBlock = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: CustomBlock.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }
    
    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension CustomBlock {
    init<Children: Sequence>(_ children: Children) where Children.Element == BlockMarkup {
        try! self.init(.customBlock(parsedRange: nil, children.map { $0.raw.markup }))
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitCustomBlock(self)
    }
}
