/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A checkbox that can represent an on/off state.
public enum Checkbox: Sendable {
    /// The checkbox is checked, representing an "on", "true", or "incomplete" state.
    case checked
    /// The checkbox is unchecked, representing an "off", "false", or "incomplete" state.
    case unchecked
}

/// A list item in an ordered or unordered list.
public struct ListItem: BlockContainer {
    public var _data: _MarkupData
    init(_ raw: RawMarkup) throws {
        guard case .listItem = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: ListItem.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }
    
    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension ListItem {
    /// Create a list item.
    /// - Parameter checkbox: An optional ``Checkbox`` for the list item.
    /// - Parameter children: The child block elements of the list item.
    init(checkbox: Checkbox? = .none, _ children: BlockMarkup...) {
        try! self.init(.listItem(checkbox: checkbox, parsedRange: nil, children.map { $0.raw.markup }))
    }

    /// Create a list item.
    /// - Parameter checkbox: An optional ``Checkbox`` for the list item.
    /// - Parameter children: The child block elements of the list item.
    init<Children: Sequence>(checkbox: Checkbox? = .none, _ children: Children) where Children.Element == BlockMarkup {
        try! self.init(.listItem(checkbox: checkbox, parsedRange: nil, children.map { $0.raw.markup }))
    }

    /// An optional ``Checkbox`` for the list item, which can indicate completion of a task, or some other off/on information.
    var checkbox: Checkbox? {
        get {
            guard case let .listItem(checkbox) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return checkbox
        }
        set {
            _data = _data.replacingSelf(.listItem(checkbox: newValue, parsedRange: nil, _data.raw.markup.copyChildren()))
        }
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitListItem(self)
    }
}
