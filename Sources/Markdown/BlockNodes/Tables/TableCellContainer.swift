/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A container of ``Table/Cell`` elements.
public protocol TableCellContainer: Markup, ExpressibleByArrayLiteral {
    /// Create a row from cells.
    ///
    /// - parameter cells: A sequence of ``Table/Cell`` elements from which to make this row.
    init<Cells: Sequence>(_ cells: Cells) where Cells.Element == Table.Cell
}

// MARK: - Public API

public extension TableCellContainer {
    /// Create a row from one cell.
    ///
    /// - parameter cell: The one cell comprising the row.
    init(_ cell: Table.Cell) {
        self.init(CollectionOfOne(cell))
    }

    /// Create a row from cells.
    ///
    /// - parameter cells: A sequence of ``Table/Cell`` elements from which to make this row.
    init(_ cells: Table.Cell...) {
        self.init(cells)
    }

    init(arrayLiteral elements: Table.Cell...) {
        self.init(elements)
    }

    /// The cells of the row.
    ///
    /// - Precondition: All children of a ``TableCellContainer`` must be a `Table.Cell`.
    var cells: LazyMapSequence<MarkupChildren, Table.Cell> {
        return children.lazy.map { $0 as! Table.Cell }
    }

    /// Replace all cells with a sequence of cells.
    ///
    /// - parameter newCells: A sequence of ``Table/Cell`` elements that will replace all of the cells in this row.
    mutating func setCells<Cells: Sequence>(_ newCells: Cells) where Cells.Element == Table.Cell {
        replaceCellsInRange(0..<childCount, with: newCells)
    }

    /// Replace cells in a range with a sequence of cells.
    mutating func replaceCellsInRange<Cells: Sequence>(_ range: Range<Int>, with incomingCells: Cells) where Cells.Element == Table.Cell {
        var rawChildren = raw.markup.copyChildren()
        rawChildren.replaceSubrange(range, with: incomingCells.map { $0.raw.markup })
        let newRaw = raw.markup.withChildren(rawChildren)
        _data = _data.replacingSelf(newRaw)
    }

    /// Append a cell to the row.
    ///
    /// - parameter cell: The cell to append to the row.
    mutating func appendCell(_ cell: Table.Cell) {
        replaceCellsInRange(childCount..<childCount, with: CollectionOfOne(cell))
    }
}
