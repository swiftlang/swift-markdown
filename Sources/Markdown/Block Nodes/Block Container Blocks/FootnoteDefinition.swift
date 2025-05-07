/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public struct FootnoteDefinition: BlockContainer {
    public var _data: _MarkupData
    init(_ raw: RawMarkup) throws {
        guard case .footnoteDefinition = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: FootnoteDefinition.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension FootnoteDefinition {
    // MARK: BasicBlockContainer

    init<Children: Sequence>(footnoteID: String, _ children: Children) where Children.Element == BlockMarkup {
        try! self.init(.footnoteDefinition(footnoteID: footnoteID, parsedRange: nil, children.map { $0.raw.markup }))
    }

    init(footnoteID: String, _ children: BlockMarkup...) {
        self.init(footnoteID: footnoteID, children)
    }

    var footnoteID: String {
        get {
            guard case let .footnoteDefinition(footnoteID: footnoteID) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return footnoteID
        }
        set {
            _data = _data.replacingSelf(.footnoteDefinition(footnoteID: newValue, parsedRange: nil, _data.raw.markup.copyChildren()))
        }
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitFootnoteDefinition(self)
    }
}
