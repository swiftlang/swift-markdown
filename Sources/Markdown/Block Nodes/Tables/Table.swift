/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


/// A table.
///
/// A table consists of a *head*, a single row of cells; and a *body*, which can contain zero or more *rows*.
///
/// There are a few invariants on the table which must be kept due to the parser's implementation of the [spec](https://github.github.com/gfm/#tables-extension-).
///
/// - All rows must have the same number of cells. Therefore, sibling rows will be expanded with empty cells to fit larger incoming rows. Trimming columns from the table requires explicit action
/// - Column alignment applies to all cells within in the same column. See ``columnAlignments``.
public struct Table: BlockMarkup {
    /// The alignment of all cells under a table column.
    public enum ColumnAlignment: Sendable {
        /// Left alignment.
        case left

        /// Center alignment.
        case center

        /// Right alignment.
        case right
    }

    public var _data: _MarkupData

    init(_ data: _MarkupData) {
        self._data = data
    }

    init(_ raw: RawMarkup) throws {
        guard case .table = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: Table.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }
}

// MARK: - Public API

public extension Table {
    /// Create a table from a header, body, and optional column alignments.
    ///
    /// - parameter columnAlignments: An optional list of alignments for each column,
    ///   truncated or expanded with `nil` to fit the table's maximum column count.
    /// - parameter header: A ``Table/Head-swift.struct`` element serving as the table's head.
    /// - parameter body: A ``Table/Body-swift.struct`` element serving as the table's body.
    init(columnAlignments: [ColumnAlignment?]? = nil,
         header: Head = Head(),
         body: Body = Body()) {
        try! self.init(RawMarkup.table(columnAlignments: columnAlignments ?? [],
                                       parsedRange: nil,
                                       header: header.raw.markup,
                                       body: body.raw.markup))
    }

    /// The maximum number of columns in each row.
    var maxColumnCount: Int {
        return max(head.childCount, body.maxColumnCount)
    }

    /// The table's header, a single row of cells.
    var head: Head {
        get {
            return child(at: 0) as! Head
        }
        set {
            _data = _data.replacingSelf(.table(columnAlignments: columnAlignments,
                                             parsedRange: nil,
                                             header: newValue.raw.markup,
                                             body: raw.markup.child(at: 1)))
        }
    }

    /// The table's body, a collection of rows.
    var body: Body {
        get {
            return child(at: 1) as! Body
        }
        set {
            _data = _data.replacingSelf(.table(columnAlignments: columnAlignments,
                                             parsedRange: nil,
                                             header: raw.markup.child(at: 0),
                                             body: newValue.raw.markup))
        }
    }

    /// Alignments to apply to each cell in each column.
    var columnAlignments: [Table.ColumnAlignment?] {
        get {
            guard case let .table(columnAlignments: alignments) = self.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return alignments
        }

        set {
            _data = _data.replacingSelf(.table(columnAlignments: newValue,
                                             parsedRange: nil,
                                             header: raw.markup.child(at: 0),
                                             body: raw.markup.child(at: 1)))
        }
    }

    /// `true` if both the ``Table/head-swift.property`` and ``Table/body-swift.property`` are empty.
    var isEmpty: Bool {
        return head.isEmpty && body.isEmpty
    }

    // MARK: Visitation

    func accept<V>(_ visitor: inout V) -> V.Result where V : MarkupVisitor {
        return visitor.visitTable(self)
    }
}

fileprivate extension Array where Element == Table.ColumnAlignment? {
    func ensuringCount(atLeast minCount: Int) -> Self {
        if count < minCount {
            return self + Array(repeating: nil, count: count - minCount)
        } else {
            return self
        }
    }
}
