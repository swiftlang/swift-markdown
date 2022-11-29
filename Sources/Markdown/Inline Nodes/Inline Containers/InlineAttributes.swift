/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A set of one or more inline attributes.
public struct InlineAttributes: InlineMarkup, InlineContainer {
    public var _data: _MarkupData

    init(_ raw: RawMarkup) throws {
        guard case .inlineAttributes = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: InlineAttributes.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension InlineAttributes {
    /// Create a set of custom inline attributes applied to zero or more child inline elements.
    init<Children: Sequence>(attributes: String, _ children: Children) where Children.Element == RecurringInlineMarkup {
        try! self.init(.inlineAttributes(attributes: attributes, parsedRange: nil, children.map { $0.raw.markup }))
    }

    /// Create a set of custom attributes applied to zero or more child inline elements.
    init(attributes: String, _ children: RecurringInlineMarkup...) {
        self.init(attributes: attributes, children)
    }
    
    /// The specified attributes in JSON5 format.
    var attributes: String {
        get {
            guard case let .inlineAttributes(attributes) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return attributes
        }
        set {
            _data = _data.replacingSelf(.inlineAttributes(attributes: newValue, parsedRange: nil, _data.raw.markup.copyChildren()))
        }
    }
    
    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitInlineAttributes(self)
    }
}
