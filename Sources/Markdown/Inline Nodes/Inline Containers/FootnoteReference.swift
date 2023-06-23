/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A reference to a footnote
public struct FootnoteReference: InlineMarkup, InlineContainer {
    public var _data: _MarkupData

    init(_ raw: RawMarkup) throws {
        guard case .footnoteReference = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: FootnoteReference.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension FootnoteReference {
    init<Children: Sequence>(footnoteID: String, _ children: Children) where Children.Element == RecurringInlineMarkup {
        try! self.init(.footnoteReference(footnoteID: footnoteID, parsedRange: nil, children.map { $0.raw.markup }))
    }

    init(footnoteID: String, _ children: RecurringInlineMarkup...) {
        self.init(footnoteID: footnoteID, children)
    }
    
    /// The specified attributes in JSON5 format.
    var footnoteID: String {
        get {
            guard case let .footnoteReference(footnoteID: footnoteID) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return footnoteID
        }
        set {
            _data = _data.replacingSelf(.footnoteReference(footnoteID: newValue, parsedRange: nil, _data.raw.markup.copyChildren()))
        }
    }
    
    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitFootnoteReference(self)
    }
}
