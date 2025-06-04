/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// The data specific to a kind of markup element.
///
/// Some elements don't currently track any specific data and act as basic containers for their children. In some cases, there is an expectation regarding children.
///
/// For example, a `Document` can't contain another `Document` and lists can only contain `ListItem`s as children. Since `RawMarkup` is a single type, these are enforced through preconditions; however, those rules are enforced as much as possible at compile time in the various `Markup` types.
enum RawMarkupData: Equatable {
    case blockQuote
    case codeBlock(String, language: String?)
    case customBlock
    case document
    case heading(level: Int)
    case thematicBreak
    case htmlBlock(String)
    case listItem(checkbox: Checkbox?)
    case orderedList(startIndex: UInt = 1)
    case unorderedList
    case paragraph
    case blockDirective(name: String, nameLocation: SourceLocation?, arguments: DirectiveArgumentText)

    case inlineCode(String)
    case customInline(String)
    case emphasis
    case image(source: String?, title: String?)
    case inlineHTML(String)
    case lineBreak
    case link(destination: String?, title: String?)
    case softBreak
    case strong
    case text(String)
    case symbolLink(destination: String?)
    case inlineAttributes(attributes: String)

    // Extensions
    case strikethrough

    // `alignments` indicate the fixed column count of every row in the table.
    case table(columnAlignments: [Table.ColumnAlignment?])
    case tableHead
    case tableBody
    case tableRow
    case tableCell(colspan: UInt, rowspan: UInt)

    case doxygenDiscussion
    case doxygenNote
    case doxygenAbstract
    case doxygenParam(name: String)
    case doxygenReturns
}

extension RawMarkupData {
    func isTableCell() -> Bool {
        switch self {
        case .tableCell:
            return true
        default:
            return false
        }
    }
}

/// The header for the `RawMarkup` managed buffer.
///
/// > Warning: **Do not mutate** anything to do with `RawMarkupHeader`
/// > or change any property to variable.
/// > Although this is a struct, this is used as the header type for a
/// > managed buffer type with reference semantics.
public struct RawMarkupHeader {
    /// The data specific to this element.
    let data: RawMarkupData

    /// The number of children.
    let childCount: Int

    /// The number of elements in this subtree, including this one.
    let subtreeCount: Int

    /// The range of a raw markup element if it was parsed from source; otherwise, `nil`.
    ///
    /// > Warning: This should only ever be mutated by `RangeAdjuster` while
    /// > parsing. **Do not** expose this through any public API.
    var parsedRange: SourceRange?
}

final class RawMarkup: ManagedBuffer<RawMarkupHeader, RawMarkup> {
    enum Error: LocalizedError {
        case concreteConversionError(from: RawMarkup, to: Markup.Type)
        var errorDescription: String? {
            switch self {
            case let .concreteConversionError(raw, to: type):
                return "Can't wrap a \(raw.data) in a \(type)"
            }
        }
    }
    private static func create(data: RawMarkupData, parsedRange: SourceRange?, children: [RawMarkup]) -> RawMarkup {
        let buffer = self.create(minimumCapacity: children.count) { _ in
            RawMarkupHeader(data: data,
                            childCount: children.count,
                            subtreeCount: /* self */ 1 + children.subtreeCount,
                            parsedRange: parsedRange)
        }
        let raw = unsafeDowncast(buffer, to: RawMarkup.self)
        var children = children
        raw.withUnsafeMutablePointerToElements { elementsBasePtr in
            elementsBasePtr.initialize(from: &children, count: children.count)
        }
        return raw
    }

    /// The data specific to this kind of element.
    var data: RawMarkupData {
        return header.data
    }

    /// Copy and retain the tail-allocated children into an `Array`.
    func copyChildren() -> [RawMarkup] {
        return self.withUnsafeMutablePointerToElements {
            return Array(UnsafeBufferPointer(start: $0, count: self.header.childCount))
        }
    }

    /// The nth `RawMarkup` child under this element.
    func child(at index: Int) -> RawMarkup {
        precondition(index < header.childCount)
        return self.withUnsafeMutablePointerToElements {
            return $0.advanced(by: index).pointee
        }
    }

    /// The number of children directly under this element.
    var childCount: Int {
        return header.childCount
    }

    /// The total number of children under this element, down to the leaves,
    /// including the element itself.
    var subtreeCount: Int {
        return header.subtreeCount
    }

    /// The range of the element if it was parsed from source; otherwise, `nil`.
    var parsedRange: SourceRange? {
        return header.parsedRange
    }

    /// The children of this element.
    var children: AnySequence<RawMarkup> {
        return AnySequence((0..<childCount).lazy.map { Int -> RawMarkup in
            self.child(at: 0)
        })
    }

    deinit {
        return self.withUnsafeMutablePointerToElements {
            $0.deinitialize(count: header.childCount)
        }
    }

    // MARK: Aspects

    /// Returns `true` if this element has the same tree structure underneath it as another element.
    func hasSameStructure(as other: RawMarkup) -> Bool {
        if self === other {
            return true
        }
        guard self.header.childCount == other.header.childCount,
            self.header.data == other.header.data else {
                return false
        }
        for i in 0..<header.childCount {
            guard self.child(at: i).hasSameStructure(as: other.child(at: i)) else {
                return false
            }
        }
        return true
    }

    // MARK: Children

    /// Returns a new `RawMarkup` element replacing the slot at the given index with a new element.
    /// - note: The new element's `range` will be `nil`, as this API creates a new element outside of the parser.
    /// - precondition: The given index must be within the bounds of the children.
    func substitutingChild(_ newChild: RawMarkup, at index: Int, preserveRange: Bool = false) -> RawMarkup {
        var newChildren = copyChildren()
        newChildren[index] = newChild

        let parsedRange: SourceRange?
        if preserveRange {
            parsedRange = header.parsedRange
        } else {
            parsedRange = newChild.header.parsedRange
        }

        return RawMarkup.create(data: header.data, parsedRange: parsedRange, children: newChildren)
    }

    func withChildren<Children: Collection>(_ newChildren: Children) -> RawMarkup where Children.Element == RawMarkup {
        return .create(data: header.data, parsedRange: header.parsedRange, children: Array(newChildren))
    }

    // MARK: Block Creation

    static func blockQuote(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .blockQuote, parsedRange: parsedRange, children: children)
    }

    static func codeBlock(parsedRange: SourceRange?, code: String, language: String?) -> RawMarkup {
        return .create(data: .codeBlock(code, language: language), parsedRange: parsedRange, children: [])
    }

    static func customBlock(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .customBlock, parsedRange: parsedRange,  children: children)
    }

    static func document(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .document, parsedRange: parsedRange, children: children)
    }

    static func heading(level: Int, parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .heading(level: level), parsedRange: parsedRange, children: children)
    }

    static func thematicBreak(parsedRange: SourceRange?) -> RawMarkup {
        return .create(data: .thematicBreak, parsedRange: parsedRange, children: [])
    }

    static func htmlBlock(parsedRange: SourceRange?, html: String) -> RawMarkup {
        return .create(data: .htmlBlock(html), parsedRange: parsedRange, children: [])
    }

    static func listItem(checkbox: Checkbox?, parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .listItem(checkbox: checkbox), parsedRange: parsedRange, children: children)
    }

    static func orderedList(parsedRange: SourceRange?, _ children: [RawMarkup], startIndex: UInt = 1) -> RawMarkup {
        return .create(data: .orderedList(startIndex: startIndex), parsedRange: parsedRange, children: children)
    }

    static func unorderedList(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .unorderedList, parsedRange: parsedRange, children: children)
    }

    static func paragraph(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .paragraph, parsedRange: parsedRange, children: children)
    }

    static func blockDirective(name: String, nameLocation: SourceLocation?, argumentText: DirectiveArgumentText, parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .blockDirective(name: name, nameLocation: nameLocation, arguments: argumentText), parsedRange: parsedRange, children: children)
    }

    // MARK: Inline Creation

    static func inlineCode(parsedRange: SourceRange?, code: String) -> RawMarkup {
        return .create(data: .inlineCode(code), parsedRange: parsedRange, children: [])
    }

    static func customInline(parsedRange: SourceRange?, text: String) -> RawMarkup {
        return .create(data: .customInline(text), parsedRange: parsedRange, children: [])
    }

    static func emphasis(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .emphasis, parsedRange: parsedRange, children: children)
    }

    static func image(source: String?, title: String?, parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .image(source: source, title: title), parsedRange: parsedRange, children: children)
    }

    static func inlineHTML(parsedRange: SourceRange?, html: String) -> RawMarkup {
        return .create(data: .inlineHTML(html), parsedRange: parsedRange, children: [])
    }

    static func lineBreak(parsedRange: SourceRange?) -> RawMarkup {
        return .create(data: .lineBreak, parsedRange: parsedRange, children: [])
    }

    static func link(destination: String?, title: String? = nil,parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .link(destination: destination, title: title), parsedRange: parsedRange, children: children)
    }

    static func softBreak(parsedRange: SourceRange?) -> RawMarkup {
        return .create(data: .softBreak, parsedRange: parsedRange, children: [])
    }

    static func strong(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .strong, parsedRange: parsedRange, children: children)
    }

    static func text(parsedRange: SourceRange?, string: String) -> RawMarkup {
        return .create(data: .text(string), parsedRange: parsedRange, children: [])
    }

    static func symbolLink(parsedRange: SourceRange?, destination: String?) -> RawMarkup {
        return .create(data: .symbolLink(destination: destination), parsedRange: parsedRange, children:  [])
    }

    static func inlineAttributes(attributes: String, parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .inlineAttributes(attributes: attributes), parsedRange: parsedRange, children: children)
    }

    // MARK: Extensions

    static func strikethrough(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .strikethrough, parsedRange: parsedRange, children: children)
    }

    static func table(columnAlignments: [Table.ColumnAlignment?], parsedRange: SourceRange?, header: RawMarkup, body: RawMarkup) -> RawMarkup {
        let maxColumnCount = max(header.childCount,
                                 body.children.reduce(0, { (result, child) -> Int in
                                    return max(result, child.childCount)
                                 }))
        let alignments = columnAlignments + Array(repeating: nil,
                                                  count: max(columnAlignments.count,
                                                             maxColumnCount) - columnAlignments.count)
        return .create(data: .table(columnAlignments: alignments), parsedRange: parsedRange, children: [header, body])
    }

    static func tableRow(parsedRange: SourceRange?, _ columns: [RawMarkup]) -> RawMarkup {
        precondition(columns.allSatisfy { $0.header.data.isTableCell() })
        return .create(data: .tableRow, parsedRange: parsedRange, children: columns)
    }

    static func tableHead(parsedRange: SourceRange?, columns: [RawMarkup]) -> RawMarkup {
        precondition(columns.allSatisfy { $0.header.data.isTableCell() })
        return .create(data: .tableHead, parsedRange: parsedRange, children: columns)
    }

    static func tableBody(parsedRange: SourceRange?, rows: [RawMarkup]) -> RawMarkup {
        precondition(rows.allSatisfy { $0.header.data == .tableRow })
        return .create(data: .tableBody, parsedRange: parsedRange, children: rows)
    }

    static func tableCell(parsedRange: SourceRange?, colspan: UInt, rowspan: UInt, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .tableCell(colspan: colspan, rowspan: rowspan), parsedRange: parsedRange, children: children)
    }

    static func doxygenDiscussion(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .doxygenDiscussion, parsedRange: parsedRange, children: children)
    }

    static func doxygenNote(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .doxygenNote, parsedRange: parsedRange, children: children)
    }

    static func doxygenAbstract(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .doxygenAbstract, parsedRange: parsedRange, children: children)
    }

    static func doxygenParam(name: String, parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .doxygenParam(name: name), parsedRange: parsedRange, children: children)
    }

    static func doxygenReturns(parsedRange: SourceRange?, _ children: [RawMarkup]) -> RawMarkup {
        return .create(data: .doxygenReturns, parsedRange: parsedRange, children: children)
    }
}

fileprivate extension Sequence where Element == RawMarkup {
    var subtreeCount: Int {
        return self.lazy.map { $0.subtreeCount }.reduce(0, +)
    }
}

extension BidirectionalCollection where Element == RawMarkup {
    var parsedRange: SourceRange? {
        if let lowerBound = first?.parsedRange?.lowerBound, let upperBound = last?.parsedRange?.upperBound {
            return lowerBound..<upperBound
        } else {
            return nil
        }
    }
}
