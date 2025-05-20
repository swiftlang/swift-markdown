/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

fileprivate extension String {
    /// A version of `self` with newline "\n" characters escaped as "\\n".
    var newlineEscaped: String {
        return replacingOccurrences(of: "\n", with: "\\n")
    }
}

/// Options when printing a debug description of a markup tree.
public struct MarkupDumpOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// Include source locations and ranges of each element in the dump.
    public static let printSourceLocations = MarkupDumpOptions(rawValue: 1 << 0)

    /// Include internal unique identifiers of each element in the dump.
    public static let printUniqueIdentifiers = MarkupDumpOptions(rawValue: 1 << 1)

    /// Print all optional information about a markup tree.
    public static let printEverything: MarkupDumpOptions = [
        .printSourceLocations,
        .printUniqueIdentifiers,
    ]
}

extension Markup {
    /// Print a debug representation of the tree.
    /// - Parameter options: options to use while printing.
    /// - Returns: a description illustrating the hierarchy and contents of each element of the tree.
    public func debugDescription(options: MarkupDumpOptions = []) -> String {
        var dumper = MarkupTreeDumper(options: options)
        dumper.visit(self)
        return dumper.result
    }
}

/// A `MarkupWalker` that dumps a textual representation of a `Markup` tree for debugging.
///
/// - note: This type is utilized by a public `Markup.dump()` method available on all markup elements.
///
/// For example, this doc comment parsed as markdown would look like the following.
///
/// ```plain
/// Document
/// ├─ Paragraph
/// │  ├─ Text "A "
/// │  ├─ InlineCode `MarkupWalker`
/// │  ├─ Text " that dumps a textual representation of a "
/// │  ├─ InlineCode `Markup`
/// │  └─ Text " tree for debugging."
/// ├─ UnorderedList
/// │  └─ ListItem
/// │     └─ Paragraph
/// │        ├─ Text "note: This type is utilized by a public "
/// │        ├─ InlineCode `Markup.dump()`
/// │        └─ Text " method available on all markup elements."
/// └─ Paragraph
///    └─ Text "For example, this doc comment parsed as markdown would look like the following."
/// ```
struct MarkupTreeDumper: MarkupWalker {
    let options: MarkupDumpOptions
    init(options: MarkupDumpOptions) {
        self.options = options
    }

    /// The resulting string built up during dumping.
    var result = ""

    /// The current path in the tree so far, used for printing edges
    /// in the dumped tree.
    private var path = [Markup]()

    private mutating func dump(_ markup: Markup, customDescription: String? = nil) {
        indent(markup)
        result += "\(type(of: markup))"
        if options.contains(.printSourceLocations),
            let range = markup.range {
            result += " @\(range.diagnosticDescription(includePath: false))"
        }
        if options.contains(.printUniqueIdentifiers) {
            if markup.parent == nil {
                result += " Root #\(markup._data.id.rootId)"
            }
            result += " #\(markup._data.id.childId)"
        }
        if let customDescription = customDescription {
            if !customDescription.starts(with: "\n") {
                result += " "
            }
            result += "\(customDescription)"
        }
        increasingDepth(markup)
    }

    mutating func defaultVisit(_ markup: Markup) {
        dump(markup)
    }

    private var lineIndentPrefix: String {
        var prefix = ""
        for (depth, element) in path.enumerated().reversed() {
            guard let lastChildIndex = element.parent?.children.reversed().first?.indexInParent,
                lastChildIndex != element.indexInParent else {
                    if depth > 0 {
                        prefix.append("   ")
                    }
                    continue
            }
            prefix.append("  │")
        }
        return String(prefix.reversed())
    }

    private mutating func indentLiteralBlock(_ string: String, from element: Markup, countLines: Bool = false) -> String {
        path.append(element)
        let prefix = lineIndentPrefix
        let result = string.split(separator: "\n").enumerated().map { (index, line) in
            let lineNumber = countLines ? "\(index + 1) " : ""
            return "\(prefix)\(lineNumber)\(line)"
        }.joined(separator: "\n")
        path.removeLast()
        return result
    }
    
    /**
     Add an indentation prefix for a markup element using the current `path`.
     - parameter markup: The `Markup` element about to be printed
     */
    private mutating func indent(_ markup: Markup) {
        if !path.isEmpty {
            result.append("\n")
        }

        result += lineIndentPrefix

        guard let lastChildIndex = markup.parent?.children.reversed().first?.indexInParent else {
            return
        }
        let treeMarker = markup.indexInParent == lastChildIndex ? "└─ " : "├─ "
        result.append(treeMarker)
    }

    /**
     Push `element` to the current path and descend into the children, popping `element` from the path when returning.

     - parameter element: The parent element you're descending into.
     */
    private mutating func increasingDepth(_ element: Markup) {
        path.append(element)
        descendInto(element)
        path.removeLast()
    }

    mutating func visitText(_ text: Text) {
        dump(text, customDescription: "\"\(text.string)\"")
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        dump(html, customDescription: "\n\(indentLiteralBlock(html.rawHTML, from: html))")
    }

    mutating func visitLink(_ link: Link) {
        dump(link, customDescription: link.destination.map { "destination: \"\($0)\"" } ?? "")
    }

    mutating func visitImage(_ image: Image) {
        var description = image.source.map { "source: \"\($0)\"" } ?? ""
        if let title = image.title {
            description += " title: \"\(title)\""
        }
        dump(image, customDescription: description)
    }

    mutating func visitHeading(_ heading: Heading) {
        dump(heading, customDescription: "level: \(heading.level)")
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        if orderedList.startIndex != 1 {
            dump(orderedList, customDescription: "startIndex: \(orderedList.startIndex)")
        } else {
            defaultVisit(orderedList)
        }
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let lines = indentLiteralBlock(codeBlock.code, from: codeBlock, countLines: false)
        dump(codeBlock, customDescription: "language: \(codeBlock.language ?? "none")\n\(lines)")
    }

    mutating func visitBlockDirective(_ blockDirective: BlockDirective) {
        var argumentsDescription: String
        if !blockDirective.argumentText.segments.isEmpty {
            var description = "\n"
            description += "├─ Argument text segments:\n"
            description += blockDirective.argumentText.segments.map { segment -> String in
                let range: String
                if options.contains(.printSourceLocations) {
                    range = segment.range.map { "@\($0.diagnosticDescription()): " } ?? ""
                } else {
                    range = ""
                }
                let segmentText = segment.untrimmedText[segment.parseIndex...].debugDescription
                return "|    \(range)\(segmentText)"
            }.joined(separator: "\n")
            
            argumentsDescription = "\n" + indentLiteralBlock(description, from: blockDirective)
        } else {
            argumentsDescription = ""
        }
        dump(blockDirective, customDescription: "name: \(blockDirective.name.debugDescription)\(argumentsDescription)")
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        dump(inlineCode, customDescription: "`\(inlineCode.code)`")
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        dump(inlineHTML, customDescription: "\(inlineHTML.rawHTML)")
    }

    mutating func visitCustomInline(_ customInline: CustomInline) {
        dump(customInline, customDescription: "customInline.text")
    }

    mutating func visitListItem(_ listItem: ListItem) {
        let checkboxDescription: String? = listItem.checkbox.map {
            switch $0 {
            case .checked: return "checkbox: [x]"
            case .unchecked: return "checkbox: [ ]"
            }
        }
        dump(listItem, customDescription: checkboxDescription)
    }

    mutating func visitTable(_ table: Table) {
        let alignments = table.columnAlignments.map {
            switch $0 {
            case nil:
                return "-"
            case .left:
                return "l"
            case .right:
                return "r"
            case .center:
                return "c"
            }
        }.joined(separator: "|")
        dump(table, customDescription: "alignments: |\(alignments)|")
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) {
        dump(symbolLink, customDescription: symbolLink.destination.map { "destination: \($0)" })
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) {
        var desc = ""
        if tableCell.colspan != 1 {
            desc += " colspan: \(tableCell.colspan)"
        }
        if tableCell.rowspan != 1 {
            desc += " rowspan: \(tableCell.rowspan)"
        }
        desc = desc.trimmingCharacters(in: .whitespaces)
        if !desc.isEmpty {
            dump(tableCell, customDescription: desc)
        } else {
            dump(tableCell)
        }
    }

    mutating func visitInlineAttributes(_ attributes: InlineAttributes) -> () {
        dump(attributes, customDescription: "attributes: `\(attributes.attributes)`")
    }

    mutating func visitDoxygenParameter(_ doxygenParam: DoxygenParameter) -> () {
        dump(doxygenParam, customDescription: "parameter: \(doxygenParam.name)")
    }
}
