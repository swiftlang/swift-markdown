import Foundation
import Benchmark
import func Benchmark.blackHole
import CommonMark
import cmark_gfm
import cmark_gfm_extensions

let sample = """
# Hello, World

This is a *simple* markdown document with some **bold** text, a [link](https://example.com), and a code span: `let x = 1`.

- First item
- Second item
- Third item
"""

struct PreparedFile {
    let name: String
    let content: String
    let cBytes: ContiguousArray<CChar>
    var cLength: Int { cBytes.count - 1 }
}

private func loadMarkdownFile(named name: String) -> PreparedFile {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Comparison
        .deletingLastPathComponent()   // Benchmarks (sources)
        .deletingLastPathComponent()   // package root
        .appendingPathComponent(name)
    let content = try! String(contentsOf: url, encoding: .utf8)
    return PreparedFile(
        name: url.lastPathComponent,
        content: content,
        cBytes: ContiguousArray(content.utf8CString)
    )
}

let files1KB = [loadMarkdownFile(named: "1kb-test-content.md")]
let files100KB = [loadMarkdownFile(named: "100kb-test-content.md")]
let files1MB = [loadMarkdownFile(named: "1mb-test-content.md")]

let sampleFile = PreparedFile(
    name: "sample",
    content: sample,
    cBytes: ContiguousArray(sample.utf8CString)
)

// MARK: - Inline corpus
//
// Short single-paragraph strings (16–512 bytes, all ASCII so byte length == character count)
// exercising the inline parser: emphasis, strong, links, code spans, autolinks, escapes, and
// nested/adjacent delimiter runs. Used by the inline-only benchmarks below.

let inlineSamples = [
    "Just *one* emphasis here.",
    "Some **bold** and *italic* text together.",
    "Read [the docs](https://example.com/docs) today.",
    "Inline `code = 1` next to **strong** words.",
    "Email <me@example.com> or click [here](https://x.io).",
    "Nested **bold with *italic* inside** still parses.",
    "A mix of *em*, **strong**, `code`, and [a link](https://a.io).",
    "Adjacent **bold**`code`*italic* with no spaces between them.",
    "Escaped \\*not emphasis\\* but [this](https://example.com) is a link.",
    "This paragraph has *several* inline elements: a [link to a page](https://example.com/page), some `inline code`, **bold phrases**, and even ***bold italic*** combined to exercise the delimiter stack.",
    "Here is a longer line that weaves together many *emphasis* runs, **strong emphasis** spans, `code spans`, and [hyperlinks](https://example.com/very/long/path?q=value) so the inline parser builds and unwinds a deep delimiter stack while resolving links and adjacent **bold**`code`*italic* runs.",
]

let inlineFiles = inlineSamples.map { content in
    PreparedFile(
        name: "inline-\(content.utf8.count)b",
        content: content,
        cBytes: ContiguousArray(content.utf8CString)
    )
}

// MARK: - GFM-feature corpus
//
// A markdown document that deliberately exercises every AST-affecting parse option enabled in the
// GFM configuration below — so the "GFM feature sample" benchmarks measure the table-span, smart-
// punctuation, footnote, strikethrough, task-list, and autolink code paths rather than plain prose.
// Note the table spans use the `"` ("ditto") rowspan marker and `||` colspan filler, matching
// `.tableRowspanDitto` + `.tableSpans`; and the prose uses straight quotes, `--`/`---`, and `...`
// so `.smart` has work to do.
let gfmFeatureSample = """
# Release notes --- "Polaris" build

The parser now beats the C library at *every* size... and it isn't close. \
We measured it on three corpora---1 KB, 100 KB, and 1 MB---using the team's \
'standard' harness. Read more at www.example.com or https://example.com/bench.

## Status

| Component   | State        | Owner            |
|:------------|:------------:|-----------------:|
| Block parse | ~~slow~~ ok  | see footnote[^a] |
| Inline      || spans two columns                |
| Tables      | done         | @maintainer      |
| "           | done         | ditto rowspan    |

- [x] Smart punctuation ("curly", 'apostrophes', en--dashes, em---dashes, ellipses...)
- [x] GFM tables with ~~colspans~~ and rowspans
- [ ] Source positions (deferred)

Footnotes are supported too[^a], and bare links like https://example.com/path?q=1
and email me@example.com become autolinks.

[^a]: A footnote definition with *inline* emphasis and a `code span`.
"""

let gfmFeatureFile = PreparedFile(
    name: "gfm-features",
    content: gfmFeatureSample,
    cBytes: ContiguousArray(gfmFeatureSample.utf8CString)
)

// MARK: - All-extensions ("GFM") configuration
//
// The GitHub-Flavored Markdown feature set plus the other AST-affecting parse options, applied
// identically to both parsers so the comparison stays apples-to-apples. The two option sets below
// MUST stay in lockstep — every cmark-swift `ParseOption` has a matching cmark-gfm extension or
// `CMARK_OPT_*` bit, and vice versa:
//
//   feature              cmark-swift ParseOption     cmark-gfm
//   tables               .tables                     "table" extension
//   strikethrough        .strikethrough              "strikethrough" extension
//   autolinks            .gfmAutolink                "autolink" extension
//   task lists           .tasklist                   "tasklist" extension
//   footnotes            .footnotes                  CMARK_OPT_FOOTNOTES
//   smart punctuation    .smart                      CMARK_OPT_SMART
//   table col/row spans  .tableSpans                 CMARK_OPT_TABLE_SPANS
//   ditto rowspan marker .tableRowspanDitto          CMARK_OPT_TABLE_ROWSPAN_DITTO
//
// The `tagfilter` extension is intentionally omitted: it's a render-time HTML sanitizer with
// no effect on the parse tree, and these benchmarks only parse.

let gfmSwiftOptions: MarkdownDocument.ParseOptions = [
    .tables, .strikethrough, .gfmAutolink, .tasklist, .footnotes,
    .smart, .tableSpans, .tableRowspanDitto,
]

// The cmark-gfm core/parser options that are NOT syntax extensions (those are attached separately
// below). Mirror of the non-extension entries in `gfmSwiftOptions`.
let gfmCParseOptions: Int32 =
    CMARK_OPT_FOOTNOTES | CMARK_OPT_SMART | CMARK_OPT_TABLE_SPANS | CMARK_OPT_TABLE_ROWSPAN_DITTO

// Registered once (thread-safe lazy global init); the pointers are global singletons owned by cmark.
// `nonisolated(unsafe)`: effectively immutable after init, and the extension pointers are not `Sendable`.
nonisolated(unsafe) let gfmCExtensions: [UnsafeMutablePointer<cmark_syntax_extension>] = {
    cmark_gfm_core_extensions_ensure_registered()
    var exts: [UnsafeMutablePointer<cmark_syntax_extension>] = []
    for name in ["table", "strikethrough", "autolink", "tasklist"] {
        if let ext = name.withCString({ cmark_find_syntax_extension($0) }) {
            exts.append(ext)
        }
    }
    return exts
}()

/// Parse one prepared file with cmark-gfm and the GFM extensions attached. A fresh parser is built
/// per call (extensions attach to a parser, not globally) — that setup is part of the real cost.
private func parseGFMWithCmarkGFM(_ file: PreparedFile) {
    let parser = cmark_parser_new(gfmCParseOptions)
    for ext in gfmCExtensions {
        cmark_parser_attach_syntax_extension(parser, ext)
    }
    file.cBytes.withUnsafeBufferPointer { buffer in
        cmark_parser_feed(parser, buffer.baseAddress, file.cLength)
    }
    let document = cmark_parser_finish(parser)
    blackHole(cmark_node_get_type(document))
    cmark_node_free(document)
    cmark_parser_free(parser)
}

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .mallocCountTotal, .throughput]
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)

    Benchmark("Parse small markdown sample (cmark-swift)") { benchmark in
        for _ in benchmark.scaledIterations {
            try! MarkdownDocument.withParsedDocument(sample) { document in blackHole(document.root.kind) }
        }
    }

    Benchmark("Parse small markdown sample (cmark-gfm)") { benchmark in
        let length = sample.utf8.count
        sample.withCString { pointer in
            benchmark.startMeasurement()
            for _ in benchmark.scaledIterations {
                let document = cmark_parse_document(pointer, length, CMARK_OPT_DEFAULT)
                blackHole(cmark_node_get_type(document))
                cmark_node_free(document)
            }
            benchmark.stopMeasurement()
        }
    }
    
    Benchmark("Parse 1 KB files (cmark-swift)") { benchmark in
        for file in files1KB {
            try! MarkdownDocument.withParsedDocument(file.content) { document in blackHole(document.root.kind) }
        }
    }
    
    Benchmark("Parse 1 KB files (cmark-gfm)") { benchmark in
        for file in files1KB {
            file.cBytes.withUnsafeBufferPointer { buffer in
                let document = cmark_parse_document(buffer.baseAddress, file.cLength, CMARK_OPT_DEFAULT)
                blackHole(cmark_node_get_type(document))
                cmark_node_free(document)
            }
        }
    }
    
    Benchmark("Parse 100 KB files (cmark-swift)") { benchmark in
        for file in files100KB {
            try! MarkdownDocument.withParsedDocument(file.content) { document in blackHole(document.root.kind) }
        }
    }
    
    Benchmark("Parse 100 KB files (cmark-gfm)") { benchmark in
        for file in files100KB {
            file.cBytes.withUnsafeBufferPointer { buffer in
                let document = cmark_parse_document(buffer.baseAddress, file.cLength, CMARK_OPT_DEFAULT)
                blackHole(cmark_node_get_type(document))
                cmark_node_free(document)
            }
        }
    }
    
    Benchmark("Parse 1 MB files (cmark-swift)") { benchmark in
        for file in files1MB {
            try! MarkdownDocument.withParsedDocument(file.content) { document in blackHole(document.root.kind) }
        }
    }
    
    Benchmark("Parse 1 MB files (cmark-gfm)") { benchmark in
        for file in files1MB {
            file.cBytes.withUnsafeBufferPointer { buffer in
                let document = cmark_parse_document(buffer.baseAddress, file.cLength, CMARK_OPT_DEFAULT)
                blackHole(cmark_node_get_type(document))
                cmark_node_free(document)
            }
        }
    }

    // MARK: Inline-only parsing of short markdown strings

    Benchmark("Parse inline strings (cmark-swift, inline-only)") { benchmark in
        for _ in benchmark.scaledIterations {
            for file in inlineFiles {
                try! MarkdownDocument.withParsedDocument(file.content, options: .inlineOnly) { document in blackHole(document.root.kind) }
            }
        }
    }

    // cmark-gfm has no public inline-only parse entry point, so it parses each string as a
    // single-paragraph document. Each corpus entry is one paragraph, so the inline work dominates.
    Benchmark("Parse inline strings (cmark-gfm)") { benchmark in
        for _ in benchmark.scaledIterations {
            for file in inlineFiles {
                file.cBytes.withUnsafeBufferPointer { buffer in
                    let document = cmark_parse_document(buffer.baseAddress, file.cLength, CMARK_OPT_DEFAULT)
                    blackHole(cmark_node_get_type(document))
                    cmark_node_free(document)
                }
            }
        }
    }

    // MARK: All extensions enabled (GFM feature set)

    Benchmark("Parse GFM feature sample (cmark-swift, GFM)") { benchmark in
        for _ in benchmark.scaledIterations {
            try! MarkdownDocument.withParsedDocument(gfmFeatureSample, options: gfmSwiftOptions) { document in blackHole(document.root.kind) }
        }
    }

    Benchmark("Parse GFM feature sample (cmark-gfm, GFM)") { benchmark in
        for _ in benchmark.scaledIterations {
            parseGFMWithCmarkGFM(gfmFeatureFile)
        }
    }

    Benchmark("Parse small markdown sample (cmark-swift, GFM)") { benchmark in
        for _ in benchmark.scaledIterations {
            try! MarkdownDocument.withParsedDocument(sample, options: gfmSwiftOptions) { document in blackHole(document.root.kind) }
        }
    }

    Benchmark("Parse small markdown sample (cmark-gfm, GFM)") { benchmark in
        for _ in benchmark.scaledIterations {
            parseGFMWithCmarkGFM(sampleFile)
        }
    }

    Benchmark("Parse 1 KB files (cmark-swift, GFM)") { benchmark in
        for file in files1KB {
            try! MarkdownDocument.withParsedDocument(file.content, options: gfmSwiftOptions) { document in blackHole(document.root.kind) }
        }
    }

    Benchmark("Parse 1 KB files (cmark-gfm, GFM)") { benchmark in
        for file in files1KB {
            parseGFMWithCmarkGFM(file)
        }
    }

    Benchmark("Parse 100 KB files (cmark-swift, GFM)") { benchmark in
        for file in files100KB {
            try! MarkdownDocument.withParsedDocument(file.content, options: gfmSwiftOptions) { document in blackHole(document.root.kind) }
        }
    }

    Benchmark("Parse 100 KB files (cmark-gfm, GFM)") { benchmark in
        for file in files100KB {
            parseGFMWithCmarkGFM(file)
        }
    }

    Benchmark("Parse 1 MB files (cmark-swift, GFM)") { benchmark in
        for file in files1MB {
            try! MarkdownDocument.withParsedDocument(file.content, options: gfmSwiftOptions) { document in blackHole(document.root.kind) }
        }
    }

    Benchmark("Parse 1 MB files (cmark-gfm, GFM)") { benchmark in
        for file in files1MB {
            parseGFMWithCmarkGFM(file)
        }
    }
}
