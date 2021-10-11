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

    // MARK: BasicInlineContainer

    init<Children>(_ children: Children) where Children : Sequence, Children.Element == InlineMarkup {
        try! self.init(RawMarkup.tableCell(parsedRange: nil, children.map { $0.raw.markup }))
    }

    // MARK: Visitation

    func accept<V>(_ visitor: inout V) -> V.Result where V : MarkupVisitor {
        return visitor.visitTableCell(self)
    }
}
