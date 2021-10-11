/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension Table {
    /// The body of a table consisting of zero or more ``Table/Row`` elements.
    public struct Body : Markup {
        public var _data: _MarkupData

        init(_ data: _MarkupData) {
            self._data = data
        }

        init(_ raw: RawMarkup) throws {
            guard case .tableBody = raw.data else {
                throw RawMarkup.Error.concreteConversionError(from: raw, to: Table.Body.self)
            }
            let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
            self.init(_MarkupData(absoluteRaw))
        }

        /// The maximum number of columns seen in all rows.
        var maxColumnCount: Int {
            return children.reduce(0) { (result, row) -> Int in
                return max(result, row.childCount)
            }
        }
    }
}

// MARK: - Public API

public extension Table.Body {
    /// Create a table body from a sequence of ``Table/Row`` elements.
    init<Rows: Sequence>(_ rows: Rows) where Rows.Element == Table.Row {
        try! self.init(RawMarkup.tableBody(parsedRange: nil, rows: rows.map { $0.raw.markup }))
    }

    /// Create a table body from a sequence of ``Table/Row`` elements.
    init(_ rows: Table.Row...) {
        self.init(rows)
    }

    /// The rows of the body.
    ///
    /// - Precondition: All children of a `ListItemContainer`
    ///   must be a `ListItem`.
    var rows: LazyMapSequence<MarkupChildren, Table.Row> {
        return children.lazy.map { $0 as! Table.Row }
    }

    /// Replace all list items with a sequence of items.
    mutating func setRows<Rows: Sequence>(_ newRows: Rows) where Rows.Element == Table.Row {
        replaceRowsInRange(0..<childCount, with: newRows)
    }

    /// Replace list items in a range with a sequence of items.
    mutating func replaceRowsInRange<Rows: Sequence>(_ range: Range<Int>, with incomingRows: Rows) where Rows.Element == Table.Row {
        var rawChildren = raw.markup.copyChildren()
        rawChildren.replaceSubrange(range, with: incomingRows.map { $0.raw.markup })
        let newRaw = raw.markup.withChildren(rawChildren)
        _data = _data.replacingSelf(newRaw)
    }

    /// Append a row to the list.
    mutating func appendRow(_ row: Table.Row) {
        replaceRowsInRange(childCount..<childCount, with: CollectionOfOne(row))
    }

    // MARK: Visitation

    func accept<V>(_ visitor: inout V) -> V.Result where V : MarkupVisitor {
        return visitor.visitTableBody(self)
    }
}
