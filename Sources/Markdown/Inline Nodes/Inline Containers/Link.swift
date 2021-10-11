/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A link.
public struct Link: InlineMarkup, InlineContainer {
    public var _data: _MarkupData

    init(_ raw: RawMarkup) throws {
        guard case .link = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: Link.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension Link {
    /// Create a link with a destination and zero or more child inline elements.
    init<Children: Sequence>(destination: String? = nil, _ children: Children) where Children.Element == RecurringInlineMarkup {

        let destinationToUse: String?
        if let d = destination, d.isEmpty {
            destinationToUse = nil
        } else {
            destinationToUse = destination
        }

        try! self.init(.link(destination: destinationToUse, parsedRange: nil, children.map { $0.raw.markup }))
    }

    /// Create a link with a destination and zero or more child inline elements.
    init(destination: String, _ children: RecurringInlineMarkup...) {
        self.init(destination: destination, children)
    }

    /// The link's destination.
    var destination: String? {
        get {
            guard case let .link(destination) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return destination
        }
        set {
            if let d = newValue, d.isEmpty {
                _data = _data.replacingSelf(.link(destination: nil, parsedRange: nil, _data.raw.markup.copyChildren()))
            } else {
                _data = _data.replacingSelf(.link(destination: newValue, parsedRange: nil, _data.raw.markup.copyChildren()))
            }
        }
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitLink(self)
    }
}
