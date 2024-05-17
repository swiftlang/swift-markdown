/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A parsed Doxygen `\discussion` command.
///
/// The Doxygen support in Swift-Markdown parses `\discussion` commands of the form
/// `\discussion description`, where `description` continues until the next blank
/// line or parsed command.
///
/// ```markdown
/// \discussion This object can give other objects in your program magical powers.
/// ```
public struct DoxygenDiscussion: BlockContainer {
    public var _data: _MarkupData

    init(_ raw: RawMarkup) throws {
        guard case .doxygenDiscussion = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: DoxygenDiscussion.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }

    public func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitDoxygenDiscussion(self)
    }
}

public extension DoxygenDiscussion {
    /// Create a new Doxygen discussion definition.
    ///
    /// - Parameter children: Block child elements.
    init<Children: Sequence>(children: Children) where Children.Element == BlockMarkup {
        try! self.init(.doxygenDiscussion(parsedRange: nil, children.map({ $0.raw.markup })))
    }

    /// Create a new Doxygen discussion definition.
    ///
    /// - Parameter children: Block child elements.
    init(children: BlockMarkup...) {
        self.init(children: children)
    }
}
