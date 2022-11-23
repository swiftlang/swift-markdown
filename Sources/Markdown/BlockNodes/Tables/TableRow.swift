/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public protocol _TableRowProtocol : TableCellContainer {}

extension Table {
    /// A row of cells in a table.
    public struct Row: Markup, _TableRowProtocol {
        public var _data: _MarkupData

        init(_ data: _MarkupData) {
            self._data = data
        }

        init(_ raw: RawMarkup) throws {
            guard case .tableRow = raw.data else {
                throw RawMarkup.Error.concreteConversionError(from: raw, to: Table.Row.self)
            }
            let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
            self.init(_MarkupData(absoluteRaw))
        }
    }
}

// MARK: - Public API

public extension Table.Row {

    // MARK: TableCellContainer

    init<Cells>(_ cells: Cells) where Cells : Sequence, Cells.Element == Table.Cell {
        try! self.init(.tableRow(parsedRange: nil, cells.map { $0.raw.markup }))
    }

    // MARK: Visitation

    func accept<V>(_ visitor: inout V) -> V.Result where V : MarkupVisitor {
        return visitor.visitTableRow(self)
    }
}
