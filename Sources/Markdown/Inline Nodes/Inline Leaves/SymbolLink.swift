/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A link to a symbol.
///
/// Symbol links are written the same as inline code spans but with
/// two backticks `\`` instead of one. The contents inside the backticks become
/// the link's destination.
///
/// Symbol links should be typically rendered with "code voice", usually
/// monospace.
public struct SymbolLink: InlineMarkup {
    public var _data: _MarkupData

    init(_ raw: RawMarkup) throws {
        guard case .symbolLink = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: SymbolLink.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension SymbolLink {
    /// Create a symbol link with a destination.
    init(destination: String? = nil) {
        try! self.init(.symbolLink(parsedRange: nil, destination: destination ?? ""))
    }

    /// The link's destination.
    var destination: String? {
        get {
            guard case let .symbolLink(destination) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return destination
        }
        set {
            if let newDestination = newValue, newDestination.isEmpty {
                _data = _data.replacingSelf(.symbolLink(parsedRange: nil, destination: nil))
            } else {
                _data = _data.replacingSelf(.symbolLink(parsedRange: nil, destination: newValue))
            }
        }
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitSymbolLink(self)
    }

    // MARK: PlainTextConvertibleMarkup

    var plainText: String {
        return "``\(destination ?? "")``"
    }
}
