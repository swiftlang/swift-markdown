/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A parsed Doxygen `\param` command.
///
/// The Doxygen support in Swift-Markdown parses `\param` commands of the form
/// `\param name description`, where `description` extends until the next blank line or the next
/// parsed command. For example, the following input will return two `DoxygenParam` instances:
///
/// ```markdown
/// \param coordinate The coordinate used to center the transformation.
/// \param matrix The transformation matrix that describes the transformation.
/// For more information about transformation matrices, refer to the Transformation
/// documentation.
/// ```
public struct DoxygenParameter: BlockContainer {
    public var _data: _MarkupData

    init(_ raw: RawMarkup) throws {
        guard case .doxygenParam = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: DoxygenParameter.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }

    public func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitDoxygenParameter(self)
    }
}

public extension DoxygenParameter {
    /// Create a new Doxygen parameter definition.
    ///
    /// - Parameter name: The name of the parameter being described.
    /// - Parameter children: Block child elements.
    init<Children: Sequence>(name: String, children: Children) where Children.Element == BlockMarkup {
        try! self.init(.doxygenParam(name: name, parsedRange: nil, children.map({ $0.raw.markup })))
    }

    /// Create a new Doxygen parameter definition.
    ///
    /// - Parameter name: The name of the parameter being described.
    /// - Parameter children: Block child elements.
    init(name: String, children: BlockMarkup...) {
        self.init(name: name, children: children)
    }

    /// The name of the parameter being described.
    var name: String {
        get {
            guard case let .doxygenParam(name) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return name
        }
        set {
            _data = _data.replacingSelf(.doxygenParam(
                name: newValue,
                parsedRange: nil,
                _data.raw.markup.copyChildren()
            ))
        }
    }
}
