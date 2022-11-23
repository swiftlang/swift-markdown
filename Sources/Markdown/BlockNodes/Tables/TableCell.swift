/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension Table {
    /// A cell in a table.
    public struct Cell: Markup, BasicInlineContainer {
        public var _data: _MarkupData
        init(_ raw: RawMarkup) throws {
            guard case .tableCell = raw.data else {
                throw RawMarkup.Error.concreteConversionError(from: raw, to: Table.Cell.self)
            }
            let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
            self.init(_MarkupData(absoluteRaw))
        }

        init(_ data: _MarkupData) {
            self._data = data
        }
    }
}

// MARK: - Public API

public extension Table.Cell {

    /// The number of columns this cell spans over.
    ///
    /// A normal, non-spanning table cell has a `colspan` of 1. A value greater than one indicates
    /// that this cell has expanded to cover up that number of columns. A value of zero means that
    /// this cell is being covered up by a previous cell in the same row.
    var colspan: UInt {
        get {
            guard case let .tableCell(colspan, _) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return colspan
        }
        set {
            _data = _data.replacingSelf(.tableCell(parsedRange: nil, colspan: newValue, rowspan: rowspan, _data.raw.markup.copyChildren()))
        }
    }

    /// The number of rows this cell spans over.
    ///
    /// A normal, non-spanning table cell has a `rowspan` of 1. A value greater than one indicates
    /// that this cell has expanded to cover up that number of rows. A value of zero means that
    /// this cell is being covered up by another cell in a row above it.
    var rowspan: UInt {
        get {
            guard case let .tableCell(_, rowspan) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return rowspan
        }
        set {
            _data = _data.replacingSelf(.tableCell(parsedRange: nil, colspan: colspan, rowspan: newValue, _data.raw.markup.copyChildren()))
        }
    }

    // MARK: BasicInlineContainer

    init<Children>(_ children: Children) where Children : Sequence, Children.Element == InlineMarkup {
        self.init(colspan: 1, rowspan: 1, children)
    }

    init<Children>(colspan: UInt, rowspan: UInt, _ children: Children) where Children : Sequence, Children.Element == InlineMarkup {
        try! self.init(RawMarkup.tableCell(parsedRange: nil, colspan: colspan, rowspan: rowspan, children.map { $0.raw.markup }))
    }

    // MARK: Visitation

    func accept<V>(_ visitor: inout V) -> V.Result where V : MarkupVisitor {
        return visitor.visitTableCell(self)
    }
}
