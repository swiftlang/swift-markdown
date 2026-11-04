/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import CommonMark

/// Minimal HTML renderer for cmark-swift's AST, used by the spec-parity test suite. Lives in the test target so the library stays parser-only; it's not a public API.
internal enum HTMLRenderer {

    internal static func render(_ doc: borrowing MarkdownDocument, tagfilter: Bool = false) -> String {
        var out = ""
        renderChildren(doc.root, into: &out, tight: false, tagfilter: tagfilter)
        return out
    }

    internal static func renderChildren(
        _ node: borrowing MarkdownNode,
        into out: inout String,
        tight: Bool,
        tagfilter: Bool
    ) {
        node.children.forEach { child in
            renderNode(child, into: &out, tight: tight, tagfilter: tagfilter)
        }
    }

    internal static func renderNode(
        _ node: borrowing MarkdownNode,
        into out: inout String,
        tight: Bool,
        tagfilter: Bool
    ) {
        switch node.kind {
        case .document:
            renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
        case .paragraph:
            if tight {
                renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
            } else {
                out += "<p>"
                renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
                out += "</p>\n"
            }
        case .heading(let level):
            out += "<h\(level)>"
            renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
            out += "</h\(level)>\n"
        case .thematicBreak:
            out += "<hr />\n"
        case .blockQuote:
            out += "<blockquote>\n"
            renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
            out += "</blockquote>\n"
        case .list:
            renderList(node, into: &out, tagfilter: tagfilter)
        case .item(let checked):
            out += "<li>"
            if let checked {
                out += checked
                    ? "<input checked=\"\" disabled=\"\" type=\"checkbox\"> "
                    : "<input disabled=\"\" type=\"checkbox\"> "
            }
            renderItemChildren(node, into: &out, tight: tight, tagfilter: tagfilter)
            out += "</li>\n"
        case .codeBlock:
            renderCodeBlock(node, into: &out)
        case .htmlBlock:
            if let lit = node.literal() {
                out += tagfilter ? filterDisallowedHTML(lit) : lit
            }
        case .text:
            if let lit = node.literal() {
                out += htmlEscape(lit)
            }
        case .softBreak:
            out += "\n"
        case .lineBreak:
            out += "<br />\n"
        case .codeInline:
            out += "<code>"
            if let lit = node.literal() {
                out += htmlEscape(lit)
            }
            out += "</code>"
        case .htmlInline:
            if let lit = node.literal() {
                out += tagfilter ? filterDisallowedHTML(lit) : lit
            }
        case .emphasis:
            out += "<em>"
            renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
            out += "</em>"
        case .strong:
            let nestedStrong = node.parent?.kind == .strong
            if !nestedStrong {
                out += "<strong>"
            }
            renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
            if !nestedStrong {
                out += "</strong>"
            }
        case .strikethrough:
            out += "<del>"
            renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
            out += "</del>"
        case .link:
            let url = node.url() ?? ""
            let title = node.title() ?? ""
            out += "<a href=\""
            out += escapeURL(url)
            out += "\""
            if !title.isEmpty {
                out += " title=\""
                out += htmlEscape(title)
                out += "\""
            }
            out += ">"
            renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
            out += "</a>"
        case .image:
            let url = node.url() ?? ""
            let title = node.title() ?? ""
            var alt = ""
            collectPlainText(node, into: &alt)
            out += "<img src=\""
            out += escapeURL(url)
            out += "\" alt=\""
            out += htmlEscape(alt)
            out += "\""
            if !title.isEmpty {
                out += " title=\""
                out += htmlEscape(title)
                out += "\""
            }
            out += " />"
        case .table:
            renderTable(node, into: &out, tagfilter: tagfilter)
        case .tableRow:
            // Handled by renderTable.
            break
        case .tableCell:
            break
        case .footnoteReference(let index):
            if let label = node.footnoteLabel() {
                let escapedLabel = htmlEscape(label)
                out += "<sup class=\"footnote-ref\"><a href=\"#fn-\(escapedLabel)\" id=\"fnref-\(escapedLabel)\" data-footnote-ref>\(index)</a></sup>"
            }
        case .footnoteDefinition:
            // Footnote defs are typically gathered into a footnote section at the end of the document; for spec-test parity we render them inline (the spec tests rarely exercise footnotes).
            renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
        case .attribute:
            // Fork-specific; render the children's text only.
            renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
        case .customBlock, .customInline:
            renderChildren(node, into: &out, tight: false, tagfilter: tagfilter)
        }
    }

    // MARK: - Lists

    private static func renderList(
        _ node: borrowing MarkdownNode,
        into out: inout String,
        tagfilter: Bool
    ) {
        guard case .list(let info) = node.kind else { return }
        let tag = info.kind == .ordered ? "ol" : "ul"
        out += "<\(tag)"
        if info.kind == .ordered, info.start != 1 {
            out += " start=\"\(info.start)\""
        }
        out += ">\n"
        node.children.forEach { item in
            renderNode(item, into: &out, tight: info.tight, tagfilter: tagfilter)
        }
        out += "</\(tag)>\n"
    }

    private static func renderItemChildren(
        _ item: borrowing MarkdownNode,
        into out: inout String,
        tight: Bool,
        tagfilter: Bool
    ) {
        var firstChild = true
        // Tracks whether the previous emitted child was a tight-rendered paragraph (text only, no trailing `\n`). If so, the next block sibling needs a separating `\n`. Other block children already end with their own `\n`, so an extra one would produce a stray blank line in the output.
        var prevWasTightParagraph = false
        item.children.forEach { child in
            let isParagraph = child.kind == .paragraph
            if tight && isParagraph {
                // In a tight list item, EVERY paragraph is unwrapped.
                // Only insert a leading `\n` when needed: the previous child either was a tight paragraph (no trailing `\n`), or - for the first paragraph after the marker - we want a clean `<li>`-attached layout when the first child is a paragraph AND there ARE later children.
                if !firstChild && prevWasTightParagraph {
                    out += "\n"
                }
                renderChildren(child, into: &out, tight: false, tagfilter: tagfilter)
                prevWasTightParagraph = true
            } else {
                if firstChild {
                    // Loose item - opener gets a newline before any block child. Tight item with a non-paragraph first child (e.g., a code block) also wants the newline.
                    out += "\n"
                } else if prevWasTightParagraph {
                    // Tight paragraph emitted (no `<p>`, no trailing `\n`), followed by a block sibling - separate with `\n`.
                    out += "\n"
                }
                renderNode(child, into: &out, tight: tight, tagfilter: tagfilter)
                prevWasTightParagraph = false
            }
            firstChild = false
        }
    }

    // MARK: - Code block

    private static func renderCodeBlock(
        _ node: borrowing MarkdownNode,
        into out: inout String
    ) {
        out += "<pre><code"
        if let info = node.codeBlockInfoString(), !info.isEmpty {
            // Take the first whitespace-separated word as the language.
            var lang = ""
            for ch in info {
                if ch == " " || ch == "\t" {
                    break
                }
                lang.append(ch)
            }
            if !lang.isEmpty {
                out += " class=\"language-"
                out += htmlEscape(lang)
                out += "\""
            }
        }
        out += ">"
        if let lit = node.literal() {
            out += htmlEscape(lit)
        }
        out += "</code></pre>\n"
    }

    // MARK: - Tables

    private static func renderTable(
        _ node: borrowing MarkdownNode,
        into out: inout String,
        tagfilter: Bool
    ) {
        out += "<table>\n"
        var sawHeader = false
        var inBody = false
        node.children.forEach { row in
            guard case .tableRow(let isHeader) = row.kind else { return }
            if isHeader {
                out += "<thead>\n"
                renderTableRow(row, into: &out, isHeader: true, tagfilter: tagfilter)
                out += "</thead>\n"
                sawHeader = true
            } else {
                if !inBody {
                    out += "<tbody>\n"
                    inBody = true
                }
                renderTableRow(row, into: &out, isHeader: false, tagfilter: tagfilter)
            }
        }
        if inBody {
            out += "</tbody>\n"
        }
        _ = sawHeader
        out += "</table>\n"
    }

    private static func renderTableRow(
        _ row: borrowing MarkdownNode,
        into out: inout String,
        isHeader: Bool,
        tagfilter: Bool
    ) {
        out += "<tr>\n"
        let tag = isHeader ? "th" : "td"
        row.children.forEach { cell in
            guard case .tableCell(let alignment, _, _) = cell.kind else { return }
            out += "<\(tag)"
            if alignment != .none {
                let align: String
                switch alignment {
                case .left: align = "left"
                case .center: align = "center"
                case .right: align = "right"
                case .none: align = ""
                }
                out += " align=\"\(align)\""
            }
            out += ">"
            renderChildren(cell, into: &out, tight: false, tagfilter: tagfilter)
            out += "</\(tag)>\n"
        }
        out += "</tr>\n"
    }

    // MARK: - Helpers

    /// GFM tagfilter extension: replace `<` with `&lt;` for a fixed set of "disallowed" raw HTML tags so that potentially dangerous tags don't render. Match is case-insensitive on the tag name. Only invoked when the test enables the `tagfilter` extension.
    private static let disallowedTags: [String] = [
        "title", "textarea", "style", "xmp", "iframe",
        "noembed", "noframes", "script", "plaintext"
    ]

    private static func filterDisallowedHTML(_ s: String) -> String {
        let bytes = Array(s.utf8)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            if b == UInt8(ascii: "<") {
                var j = i + 1
                if j < bytes.count, bytes[j] == UInt8(ascii: "/") {
                    j += 1
                }
                let nameStart = j
                while j < bytes.count {
                    let c = bytes[j]
                    let isLetter = (c >= UInt8(ascii: "a") && c <= UInt8(ascii: "z"))
                        || (c >= UInt8(ascii: "A") && c <= UInt8(ascii: "Z"))
                    if !isLetter {
                        break
                    }
                    j += 1
                }
                if j > nameStart {
                    let nameBytes = bytes[nameStart..<j]
                    let lower = String(decoding: nameBytes, as: UTF8.self).lowercased()
                    if disallowedTags.contains(lower) {
                        out.append(contentsOf: "&lt;".utf8)
                        i += 1
                        continue
                    }
                }
            }
            out.append(b)
            i += 1
        }
        return String(decoding: out, as: UTF8.self)
    }

    private static func collectPlainText(
        _ node: borrowing MarkdownNode,
        into out: inout String
    ) {
        node.children.forEach { child in
            if let lit = child.literal() {
                out += lit
            } else {
                collectPlainText(child, into: &out)
            }
        }
    }

    /// Replace `\<ASCII punct>` sequences with the punctuation character, per CommonMark backslash-escape rules. Used by link/image URL and title rendering since the parser preserves the original bytes.
    private static func unescapeBackslashes(_ s: String) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(s.utf8.count)
        let bytes = Array(s.utf8)
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            if b == 0x5C, i + 1 < bytes.count {
                let next = bytes[i + 1]
                if isASCIIPunctByte(next) {
                    out.append(next)
                    i += 2
                    continue
                }
            }
            out.append(b)
            i += 1
        }
        return String(decoding: out, as: UTF8.self)
    }

    private static func isASCIIPunctByte(_ b: UInt8) -> Bool {
        switch b {
        case 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29,
             0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
             0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40,
             0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60,
             0x7B, 0x7C, 0x7D, 0x7E:
            return true
        default:
            return false
        }
    }

    /// HTML-escape `&`, `<`, `>`, `"` per cmark behavior. Non-ASCII bytes pass through unchanged so the resulting String preserves the source's UTF-8 encoding.
    internal static func htmlEscape(_ s: String) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(s.utf8.count)
        for byte in s.utf8 {
            switch byte {
            case 0x26: out.append(contentsOf: "&amp;".utf8)
            case 0x3C: out.append(contentsOf: "&lt;".utf8)
            case 0x3E: out.append(contentsOf: "&gt;".utf8)
            case 0x22: out.append(contentsOf: "&quot;".utf8)
            default: out.append(byte)
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// Percent-encode characters in a URL per cmark/houdini rules. Bytes that need escaping: control chars, space, `<`, `>`, `"`, `\\`, `` ` ``, `^`, `{`, `|`, `}`, plus all non-ASCII. `&` becomes `&amp;` (HTML-escaped, not percent-encoded). `%` is preserved if followed by 2 hex digits (already-encoded sequences); otherwise percent-encoded.
    internal static func escapeURL(_ s: String) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(s.utf8.count)
        let bytes = Array(s.utf8)
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            switch b {
            case 0x26:
                out.append(contentsOf: "&amp;".utf8)
                i += 1
            case 0x25:
                if i + 2 < bytes.count,
                   isHexDigit(bytes[i + 1]),
                   isHexDigit(bytes[i + 2]) {
                    out.append(0x25)
                    out.append(bytes[i + 1])
                    out.append(bytes[i + 2])
                    i += 3
                } else {
                    out.append(contentsOf: "%25".utf8)
                    i += 1
                }
            default:
                if needsPercentEncoding(b) {
                    out.append(0x25)
                    out.append(contentsOf: hexUpperBytes(b))
                    i += 1
                } else {
                    out.append(b)
                    i += 1
                }
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    private static func needsPercentEncoding(_ b: UInt8) -> Bool {
        if b < 0x21 { return true }     // controls + space
        if b >= 0x80 { return true }    // non-ASCII
        switch b {
        case 0x22, 0x3C, 0x3E, 0x5B, 0x5C, 0x5D, 0x5E,
             0x60, 0x7B, 0x7C, 0x7D, 0x7F:
            return true
        default:
            return false
        }
    }

    private static func isHexDigit(_ b: UInt8) -> Bool {
        (b >= 0x30 && b <= 0x39)
            || (b >= 0x41 && b <= 0x46)
            || (b >= 0x61 && b <= 0x66)
    }

    private static func hexUpper(_ b: UInt8) -> String {
        let hi = Int(b >> 4)
        let lo = Int(b & 0x0F)
        let table: [Character] = ["0","1","2","3","4","5","6","7",
                                   "8","9","A","B","C","D","E","F"]
        return String([table[hi], table[lo]])
    }

    private static func hexUpperBytes(_ b: UInt8) -> [UInt8] {
        let hi = Int(b >> 4)
        let lo = Int(b & 0x0F)
        let table: [UInt8] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
                              0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46]
        return [table[hi], table[lo]]
    }
}
