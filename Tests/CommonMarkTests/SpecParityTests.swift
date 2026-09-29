/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import CommonMark

internal struct SpecExample: Sendable {
    var section: String
    var number: Int
    var markdown: String
    var expectedHTML: String
    var extensions: [String]
}

internal enum SpecParser {
    internal static func parse(_ text: String) -> [SpecExample] {
        var examples: [SpecExample] = []
        var section = ""
        var number = 0
        let fence = String(repeating: "`", count: 32)
        let lines = text.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("# ") || line.hasPrefix("## ")
                || line.hasPrefix("### ") || line.hasPrefix("#### ")
                || line.hasPrefix("##### ") || line.hasPrefix("###### ") {
                let trimmed = line.drop(while: { $0 == "#" || $0 == " " })
                section = String(trimmed)
            }
            if line.hasPrefix(fence) && line.contains("example") {
                // Trailing text after `example` lists per-example extensions.
                let after = line.dropFirst(fence.count).trimmingCharacters(in: .whitespaces)
                let parts = after.split(separator: " ").map(String.init)
                let exts = parts.dropFirst().map { String($0) }
                var md: [String] = []
                var html: [String] = []
                var inHTML = false
                i += 1
                while i < lines.count {
                    let l = lines[i]
                    if l == fence {
                        break
                    }
                    if l == "." && !inHTML {
                        inHTML = true
                        i += 1
                        continue
                    }
                    if inHTML {
                        html.append(l)
                    } else {
                        md.append(l)
                    }
                    i += 1
                }
                number += 1
                examples.append(SpecExample(
                    section: section,
                    number: number,
                    markdown: (md.joined(separator: "\n") + "\n").replacingOccurrences(of: "→", with: "\t"),
                    expectedHTML: (html.joined(separator: "\n") + (html.isEmpty ? "" : "\n")).replacingOccurrences(of: "→", with: "\t"),
                    extensions: exts
                ))
            }
            i += 1
        }
        return examples
    }
}

@Suite("Spec parity")
struct SpecParityTests {

    private static func loadSpec() throws -> [SpecExample] {
        let here = URL(fileURLWithPath: #filePath)
        let resource = here.deletingLastPathComponent().appendingPathComponent("spec.txt")
        let text = try String(contentsOf: resource, encoding: .utf8)
        return SpecParser.parse(text)
    }

    /// Map a per-example extension annotation (e.g. `autolink`, `table`, `strikethrough`, `tagfilter`) to the corresponding `MarkdownDocument.ParseOptions` bits. Tasklist + footnotes aren't called out in the spec, so we include them implicitly when any extension is set - they don't otherwise interfere.
    private static func options(forExtensions extensions: [String]) -> MarkdownDocument.ParseOptions {
        var opts: MarkdownDocument.ParseOptions = []
        for ext in extensions {
            switch ext {
            case "autolink":      opts.formUnion(.gfmAutolink)
            case "strikethrough": opts.formUnion(.strikethrough)
            case "table":         opts.formUnion(.tables)
            case "tagfilter":     break // not implemented
            default: break
            }
        }
        // Tasklist and footnotes aren't gated by per-example annotations in the spec, so always include them.
        opts.formUnion([.tasklist, .footnotes])
        return opts
    }

    @Test("test all spec examples")
    func testAll() throws {
        let examples = try Self.loadSpec()
        // Make sure we've got enough test data here
        #expect(examples.count > 600)
        for ex in examples {
            let source = ex.markdown
            try MarkdownDocument.withParsedDocument(source, options: Self.options(forExtensions: ex.extensions)) { doc in
            let actual = HTMLRenderer.render(doc, tagfilter: ex.extensions.contains("tagfilter"))
            if actual != ex.expectedHTML {
                var debugOutput = "=== #\(ex.number) [\(ex.section)] ==="
                debugOutput += "input:    \(ex.markdown.debugDescription)"
                debugOutput += "expected: \(ex.expectedHTML.debugDescription)"
                debugOutput += "got:      \(actual.debugDescription)"
                #expect(actual == ex.expectedHTML, Comment(rawValue: debugOutput))
            }
            }
        }
    }
}
