/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A parsed Doxygen `\returns`, `\return`, or `\result` command.
///
/// The Doxygen support in Swift-Markdown parses `\returns` commands of the form
/// `\returns description`, where `description` continues until the next blank line or parsed
/// command. The commands `\return` and `\result` are also accepted, with the same format.
///
/// ```markdown
/// \returns A freshly-created object.
/// ```
public struct DoxygenReturns: BlockContainer {
    public var _data: _MarkupData

    init(_ raw: RawMarkup) throws {
        guard case .doxygenReturns = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: DoxygenReturns.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }

    public func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitDoxygenReturns(self)
    }
}

public extension DoxygenReturns {
    /// Create a new Doxygen parameter definition.
    ///
    /// - Parameter name: The name of the parameter being described.
    /// - Parameter children: Block child elements.
    init<Children: Sequence>(children: Children) where Children.Element == BlockMarkup {
        try! self.init(.doxygenReturns(parsedRange: nil, children.map({ $0.raw.markup })))
    }

    /// Create a new Doxygen parameter definition.
    ///
    /// - Parameter name: The name of the parameter being described.
    /// - Parameter children: Block child elements.
    init(children: BlockMarkup...) {
        self.init(children: children)
    }
}
