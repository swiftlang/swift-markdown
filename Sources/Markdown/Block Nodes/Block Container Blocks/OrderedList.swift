/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An ordered list.
public struct OrderedList: ListItemContainer, BlockMarkup {    
    public var _data: _MarkupData
    init(_ raw: RawMarkup) throws {
        guard case .orderedList = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: OrderedList.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }
    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension OrderedList {
    // MARK: ListItemContainer

    init<Items: Sequence>(_ items: Items) where Items.Element == ListItem {
        try! self.init(.orderedList(parsedRange: nil, items.map { $0.raw.markup }))
    }

    /// The starting index for the list.
    ///
    /// The default starting index in CommonMark is 1. In this case, clients may use any desired index for this list.
    var start: Int {
        get {
            guard case let .orderedList(start) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return start
        }
        set {
            precondition(newValue > 0, "List start must be 1 or greater")
            guard start != newValue else {
                return
            }
            _data = _data.replacingSelf(.orderedList(parsedRange: nil, _data.raw.markup.copyChildren(), start: newValue))
        }
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitOrderedList(self)
    }
}
