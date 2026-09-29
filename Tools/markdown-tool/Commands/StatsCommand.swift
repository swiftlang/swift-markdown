/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import CommonMark
import Foundation

extension MarkdownCommand {
    /// A command to parse a document and print a high-level summary of its content (node counts, kinds, content sizes) without rendering it.
    struct Stats: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stats",
            abstract: "Summarize the structure and content of a Markdown document.",
            discussion: """
            Parses the document and reports a high-level overview: the total number \
            of nodes, a histogram of node kinds, the tree depth, and the sizes of the \
            text-bearing fields. Useful for understanding what a Markdown file contains \
            without printing or rendering the whole thing.

            Given several files, reports the combined totals and the per-file averages \
            instead of the detailed per-node breakdown. Files that cannot be read or \
            parsed are skipped and listed at the end.
            """
        )

        @Argument(help: "Paths to Markdown files. Reads standard input if none are given or \"-\".")
        var paths: [String] = []

        @Flag(
            inversion: .prefixedNo,
            help: "Enable GFM extensions: tables, strikethrough, autolinks, task lists, and footnotes."
        )
        var gfm = true

        func run() throws {
            var options: MarkdownDocument.ParseOptions = []
            if gfm {
                options.formUnion([.tables, .strikethrough, .gfmAutolink, .tasklist, .footnotes])
            }

            let inputPaths = paths.isEmpty ? ["-"] : paths

            // A single document gets the detailed per-node report.
            if inputPaths.count == 1 {
                let path = inputPaths[0]
                let content = try readContent(of: path)
                let collector = StatsCollector()
                try MarkdownDocument.withParsedDocument(content, options: options) { document in
                    walk(document.root, depth: 0, into: collector)
                    printReport(name: name(of: path), source: content, document: document, options: options, collector: collector)
                }
                return
            }

            // Each document gets its own collector so the aggregate report can show both the combined totals/averages and the per-file min/max distribution.
            var files: [FileStats] = []
            var failures: [(name: String, message: String)] = []

            for path in inputPaths {
                do {
                    let content = try readContent(of: path)
                    let collector = StatsCollector()
                    let stats = try MarkdownDocument.withParsedDocument(content, options: options) { document -> FileStats in
                        walk(document.root, depth: 0, into: collector)
                        return FileStats(
                            collector: collector,
                            sourceBytes: content.utf8.count,
                            materializedBytes: document._materializedStringSize,
                            lines: document.lineCount,
                            segments: document._segmentCount
                        )
                    }
                    files.append(stats)
                } catch {
                    failures.append((name(of: path), "\(error)"))
                }
            }

            printAggregateReport(
                files: files,
                options: options,
                failures: failures
            )
        }

        // MARK: - Input

        private func name(of path: String) -> String {
            path == "-" ? "<stdin>" : path
        }

        private func readContent(of path: String) throws -> String {
            if path == "-" {
                let data = FileHandle.standardInput.readDataToEndOfFile()
                return String(decoding: data, as: UTF8.self)
            }
            return try String(contentsOfFile: path, encoding: .utf8)
        }
    }
}

// MARK: - Traversal

/// Recursively visit every node in the tree, feeding each to the collector.
private func walk(_ node: borrowing MarkdownNode, depth: Int, into collector: StatsCollector) {
    collector.record(node, depth: depth)
    node.children.forEach { child in
        walk(child, depth: depth + 1, into: collector)
    }
}

/// Accumulates statistics as the tree is walked. A reference type so it can be shared across the non-escaping traversal closures without `inout` capture.
private final class StatsCollector {
    var nodeCount = 0
    var leafCount = 0
    var maxDepth = 0
    var blockCount = 0
    var inlineCount = 0
    var kindCounts: [String: Int] = [:]

    // Literal-bearing content (text, code spans, code/HTML blocks, inline HTML).
    var literalNodeCount = 0
    var literalBytes = 0
    var largestLiteral = 0

    // Headings, indexed 1...6.
    var headingByLevel = [Int](repeating: 0, count: 7)

    var linkCount = 0
    var linkWithTitleCount = 0
    var imageCount = 0

    var codeBlockCount = 0
    var fencedCodeCount = 0
    var codeBlockBytes = 0

    var listCount = 0
    var bulletListCount = 0
    var orderedListCount = 0
    var tightListCount = 0

    var tableCount = 0
    var tableRowCount = 0
    var tableCellCount = 0

    var taskItemCount = 0
    var checkedTaskCount = 0

    var footnoteDefinitionCount = 0
    var footnoteReferenceCount = 0

    func record(_ node: borrowing MarkdownNode, depth: Int) {
        nodeCount += 1
        if depth > maxDepth { maxDepth = depth }
        if node.isLeaf { leafCount += 1 }

        let kind = node.kind
        kindCounts[displayName(kind), default: 0] += 1
        if kind.isBlock { blockCount += 1 } else { inlineCount += 1 }

        switch kind {
        case .text, .codeInline, .htmlInline, .codeBlock, .htmlBlock:
            let bytes: Int
            switch node.stringContent {
            case .text(let s): bytes = s.utf8.count
            case .codeBlock(_, let body): bytes = body.utf8.count
            case .htmlBlock(let body): bytes = body.utf8.count
            default: bytes = 0
            }
            literalNodeCount += 1
            literalBytes += bytes
            if bytes > largestLiteral { largestLiteral = bytes }
        default:
            break
        }

        switch kind {
        case .heading(let level):
            if (1...6).contains(level) {
                headingByLevel[level] += 1
            }
        case .link:
            linkCount += 1
            if case .link(_, let title) = node.stringContent, !title.isEmpty { linkWithTitleCount += 1 }
        case .image:
            imageCount += 1
        case .codeBlock(let info):
            codeBlockCount += 1
            if info.isFenced { fencedCodeCount += 1 }
            switch node.stringContent {
            case .codeBlock(_, let body): codeBlockBytes += body.utf8.count
            default: break
            }
        case .list(let info):
            listCount += 1
            if info.kind == .ordered { orderedListCount += 1 } else { bulletListCount += 1 }
            if info.tight { tightListCount += 1 }
        case .item(let checked):
            if let checked {
                taskItemCount += 1
                if checked { checkedTaskCount += 1 }
            }
        case .table:
            tableCount += 1
        case .tableRow:
            tableRowCount += 1
        case .tableCell:
            tableCellCount += 1
        case .footnoteDefinition:
            footnoteDefinitionCount += 1
        case .footnoteReference:
            footnoteReferenceCount += 1
        default:
            break
        }
    }
}

// MARK: - Reporting

/// Per-file statistics gathered during the multi-document walk. The document-level sizes are captured alongside the walked-tree `collector` so the aggregate report can compute each metric's total, average, and min/max across all files.
private struct FileStats {
    let collector: StatsCollector
    let sourceBytes: Int
    let materializedBytes: Int
    let lines: Int
    let segments: Int
}

private func printReport(
    name: String,
    source: String,
    document: borrowing MarkdownDocument,
    options: MarkdownDocument.ParseOptions,
    collector c: StatsCollector
) {
    let byteCount = source.utf8.count
    let lineCount = document.lineCount

    print("Document: \(name)")
    print("Source:   \(byteCount.formatted()) bytes, \(lineCount.formatted()) lines")
    print("Strings:  \(document._materializedStringSize.formatted()) bytes materialized")
    print("Options:  \(describe(options))")
    print("")

    print("Nodes:    \(c.nodeCount.formatted()) total  (\(c.blockCount.formatted()) block, \(c.inlineCount.formatted()) inline)")
    print("          max depth \(c.maxDepth), \(c.leafCount.formatted()) leaves")
    print("Segments: \(document._segmentCount.formatted()) total")
    print("")

    print("Node kinds:")
    let rows = c.kindCounts
        .map { (name: $0.key, count: $0.value) }
        .filter { $0.count > 0 }
        .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    let nameWidth = rows.map(\.name.count).max() ?? 0
    for row in rows {
        let label = row.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
        print("  \(label)  \(row.count.formatted())")
    }
    print("")

    print("Literal content: \(c.literalBytes.formatted()) bytes across \(c.literalNodeCount.formatted()) nodes (largest \(c.largestLiteral.formatted()) bytes)")

    if headingTotal(c) > 0 {
        let levels = (1...6)
            .filter { c.headingByLevel[$0] > 0 }
            .map { "h\($0):\(c.headingByLevel[$0])" }
            .joined(separator: " ")
        print("Headings:        \(headingTotal(c).formatted())  (\(levels))")
    }
    if c.linkCount > 0 {
        print("Links:           \(c.linkCount.formatted())  (\(c.linkWithTitleCount.formatted()) with title)")
    }
    if c.imageCount > 0 {
        print("Images:          \(c.imageCount.formatted())")
    }
    if c.codeBlockCount > 0 {
        let indented = c.codeBlockCount - c.fencedCodeCount
        print("Code blocks:     \(c.codeBlockCount.formatted())  (\(c.fencedCodeCount.formatted()) fenced, \(indented.formatted()) indented), \(c.codeBlockBytes.formatted()) bytes")
    }
    if c.listCount > 0 {
        let loose = c.listCount - c.tightListCount
        print("Lists:           \(c.listCount.formatted())  (\(c.bulletListCount.formatted()) bullet, \(c.orderedListCount.formatted()) ordered; \(c.tightListCount.formatted()) tight, \(loose.formatted()) loose)")
    }
    if c.taskItemCount > 0 {
        print("Task items:      \(c.taskItemCount.formatted())  (\(c.checkedTaskCount.formatted()) checked)")
    }
    if c.tableCount > 0 {
        print("Tables:          \(c.tableCount.formatted())  (\(c.tableRowCount.formatted()) rows, \(c.tableCellCount.formatted()) cells)")
    }
    if c.footnoteDefinitionCount > 0 || c.footnoteReferenceCount > 0 {
        print("Footnotes:       \(c.footnoteDefinitionCount.formatted()) definitions, \(c.footnoteReferenceCount.formatted()) references")
    }
}

private func headingTotal(_ c: StatsCollector) -> Int {
    c.headingByLevel.reduce(0, +)
}

// MARK: - Aggregate reporting

/// Report combined totals, per-file averages, and the min/max distribution across several documents.
private func printAggregateReport(
    files: [FileStats],
    options: MarkdownDocument.ParseOptions,
    failures: [(name: String, message: String)]
) {
    let fileCount = files.count
    let attempted = fileCount + failures.count
    print("Documents: \(fileCount.formatted()) of \(attempted.formatted()) files parsed")
    print("Options:   \(describe(options))")
    print("")

    guard fileCount > 0 else {
        print("No files parsed successfully.")
        printFailures(failures)
        return
    }

    // Each metric row carries its per-file values so the table can show the total, average, and the min/max distribution.
    func values(_ extract: (FileStats) -> Int) -> [Int] { files.map(extract) }

    var rows: [(label: String, values: [Int])] = [
        ("Source bytes", values { $0.sourceBytes }),
        ("Materialized bytes", values { $0.materializedBytes }),
        ("Lines", values { $0.lines }),
        ("Nodes", values { $0.collector.nodeCount }),
        ("  block", values { $0.collector.blockCount }),
        ("  inline", values { $0.collector.inlineCount }),
        ("Leaf nodes", values { $0.collector.leafCount }),
        ("Segments", values { $0.segments }),
        ("Literal bytes", values { $0.collector.literalBytes }),
        ("Literal nodes", values { $0.collector.literalNodeCount }),
    ]
    func appendIfPresent(_ label: String, _ extract: (FileStats) -> Int) {
        let vals = values(extract)
        if vals.reduce(0, +) > 0 { rows.append((label, vals)) }
    }
    appendIfPresent("Headings") { headingTotal($0.collector) }
    appendIfPresent("Links") { $0.collector.linkCount }
    appendIfPresent("Images") { $0.collector.imageCount }
    appendIfPresent("Code blocks") { $0.collector.codeBlockCount }
    appendIfPresent("Code-block bytes") { $0.collector.codeBlockBytes }
    appendIfPresent("Lists") { $0.collector.listCount }
    appendIfPresent("Task items") { $0.collector.taskItemCount }
    appendIfPresent("Tables") { $0.collector.tableCount }
    appendIfPresent("Footnote defs") { $0.collector.footnoteDefinitionCount }
    appendIfPresent("Footnote refs") { $0.collector.footnoteReferenceCount }

    printMetricTable(rows)
    print("")
    let maxDepth = files.map { $0.collector.maxDepth }.max() ?? 0
    let largestLiteral = files.map { $0.collector.largestLiteral }.max() ?? 0
    print("Maxima:   tree depth \(maxDepth), largest literal \(largestLiteral.formatted()) bytes")

    // Node-kind histogram across all documents.
    let allKindLabels = Set(files.flatMap { $0.collector.kindCounts.keys })
    let kindRows = allKindLabels
        .map { label in (label: label, values: values { $0.collector.kindCounts[label] ?? 0 }) }
        .filter { $0.values.reduce(0, +) > 0 }
        .sorted {
            let l = $0.values.reduce(0, +), r = $1.values.reduce(0, +)
            return l != r ? l > r : $0.label < $1.label
        }
    if !kindRows.isEmpty {
        print("")
        print("Node kinds:")
        printMetricTable(kindRows, indent: "  ")
    }

    printFailures(failures)
}

private func printFailures(_ failures: [(name: String, message: String)]) {
    guard !failures.isEmpty else { return }
    print("")
    print("Skipped \(failures.count.formatted()) file(s):")
    for failure in failures {
        let detail = failure.message.isEmpty ? "could not be parsed" : failure.message
        print("  \(failure.name): \(detail)")
    }
}

/// Print a `label | median | min | distribution | max | total` table, right-aligning the numeric columns. The median is the middle per-file value, `min`/`max` are the smallest and largest per-file values, the distribution is a density histogram (taller blocks = more files) over the range between them, and the total is the sum of each row's per-file values.
private func printMetricTable(
    _ rows: [(label: String, values: [Int])],
    indent: String = ""
) {
    let totals = rows.map { $0.values.reduce(0, +).formatted() }
    let medians = rows.map {
        median(of: $0.values).formatted(.number.precision(.fractionLength(0...1)))
    }
    let mins = rows.map { ($0.values.min() ?? 0).formatted() }
    let maxes = rows.map { ($0.values.max() ?? 0).formatted() }
    let bars = rows.map { histogramBar(for: $0.values) }

    let labelWidth = rows.map { indent.count + $0.label.count }.max() ?? 0
    let medianWidth = max(medians.map(\.count).max() ?? 0, "median".count)
    let minWidth = max(mins.map(\.count).max() ?? 0, "min".count)
    let barWidth = histogramBuckets + 2  // interior plus the two brackets
    let maxWidth = max(maxes.map(\.count).max() ?? 0, "max".count)

    print("\(rightPad("", labelWidth))  \(leftPad("median", medianWidth))  \(leftPad("min", minWidth))  \(rightPad("distribution", barWidth))  \(leftPad("max", maxWidth))  total")
    for (i, row) in rows.enumerated() {
        let label = rightPad(indent + row.label, labelWidth)
        print("\(label)  \(leftPad(medians[i], medianWidth))  \(leftPad(mins[i], minWidth))  \(bars[i])  \(leftPad(maxes[i], maxWidth))  \(totals[i])")
    }
}

/// The median of a list of per-file values. For an even count, the mean of the two middle values; `0` for an empty list.
private func median(of values: [Int]) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let mid = sorted.count / 2
    if sorted.count.isMultiple(of: 2) {
        return Double(sorted[mid - 1] + sorted[mid]) / 2
    }
    return Double(sorted[mid])
}

/// Number of buckets (interior cells) in a distribution histogram.
private let histogramBuckets = 16

/// Block-element glyphs for histogram bar heights, shortest to tallest.
private let histogramLevels: [Character] = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

/// A `[ ▂█▃ ]` density histogram of a row's per-file values. The range `[min, max]` is split into `histogramBuckets` equal buckets; each bucket's glyph height is scaled to the most-populated bucket (the tallest block), so the bar shows where files cluster, not just the spread. Empty buckets are blank.
private func histogramBar(for values: [Int]) -> String {
    guard let lo = values.min(), let hi = values.max() else { return "" }

    var counts = [Int](repeating: 0, count: histogramBuckets)
    if hi <= lo {
        // All files share the same value: everything lands in the first bucket.
        counts[0] = values.count
    } else {
        let span = Double(hi - lo)
        for value in values {
            let bucket = min(histogramBuckets - 1, Int(Double(value - lo) / span * Double(histogramBuckets)))
            counts[bucket] += 1
        }
    }

    let peak = counts.max() ?? 0
    var cells = ""
    for count in counts {
        if count == 0 {
            cells.append(" ")
        } else {
            let level = min(histogramLevels.count - 1, Int(Double(count) / Double(peak) * Double(histogramLevels.count - 1) + 0.5))
            cells.append(histogramLevels[level])
        }
    }
    return "[\(cells)]"
}

private func rightPad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
}

private func leftPad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : String(repeating: " ", count: width - s.count) + s
}

/// A human-readable summary of which parse options are enabled.
private func describe(_ options: MarkdownDocument.ParseOptions) -> String {
    var names: [String] = []
    if options.contains(.tables) { names.append("tables") }
    if options.contains(.strikethrough) { names.append("strikethrough") }
    if options.contains(.gfmAutolink) { names.append("autolinks") }
    if options.contains(.tasklist) { names.append("tasklist") }
    if options.contains(.footnotes) { names.append("footnotes") }
    return names.isEmpty ? "(none)" : names.joined(separator: ", ")
}

/// Lowercase display name for a node kind.
private func displayName(_ kind: MarkdownNode.Kind) -> String {
    switch kind {
    case .document: return "document"
    case .blockQuote: return "blockQuote"
    case .list: return "list"
    case .item: return "item"
    case .codeBlock: return "codeBlock"
    case .htmlBlock: return "htmlBlock"
    case .customBlock: return "customBlock"
    case .paragraph: return "paragraph"
    case .heading: return "heading"
    case .thematicBreak: return "thematicBreak"
    case .footnoteDefinition: return "footnoteDefinition"
    case .table: return "table"
    case .tableRow: return "tableRow"
    case .tableCell: return "tableCell"
    case .text: return "text"
    case .softBreak: return "softBreak"
    case .lineBreak: return "lineBreak"
    case .codeInline: return "code"
    case .htmlInline: return "htmlInline"
    case .customInline: return "customInline"
    case .emphasis: return "emphasis"
    case .strong: return "strong"
    case .link: return "link"
    case .image: return "image"
    case .footnoteReference: return "footnoteReference"
    case .strikethrough: return "strikethrough"
    case .attribute: return "attribute"
    }
}
