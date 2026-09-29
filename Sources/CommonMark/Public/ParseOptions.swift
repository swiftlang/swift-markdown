/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension MarkdownDocument {
    /// Options that control how a `MarkdownDocument` parses its source.
    ///
    /// Pass a set of options when creating a document to enable GitHub Flavored Markdown extensions (tables, strikethrough, autolinks, task lists, and footnotes), to turn on source-position tracking, or to select an inline-only parsing mode. The default value (an empty set) parses plain CommonMark.
    ///
    ///     let options: MarkdownDocument.ParseOptions = [.tables, .strikethrough, .footnotes]
    ///     try MarkdownDocument.withParsedDocument(source, options: options) { doc in
    ///         // ...
    ///     }
    public struct ParseOptions: OptionSet, Sendable, Hashable {
        /// The bit mask that represents this set of options.
        public let rawValue: Int

        /// Creates a set of parse options from a raw bit mask.
        ///
        /// Prefer combining the named options, such as `.tables` or `.footnotes`, rather than constructing a value from a raw bit mask directly.
        ///
        /// - Parameter rawValue: The bit mask that represents the options.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Tracks a source range for each node, which you read with `MarkdownNode.sourceRange`.
        ///
        /// Without this option, the parser does no position bookkeeping and `MarkdownNode.sourceRange` returns `nil`.
        public static let sourcePosition = MarkdownDocument.ParseOptions(rawValue: 1 << 1)

        /// Converts straight quotes to curly quotes, `--` to an en dash, `---` to an em dash, and `...` to an ellipsis.
        public static let smart = MarkdownDocument.ParseOptions(rawValue: 1 << 10)

        /// Parses footnote references and definitions, written as `[^label]` and `[^label]:`.
        public static let footnotes = MarkdownDocument.ParseOptions(rawValue: 1 << 13)

        /// Requires two tildes for strikethrough, as in `~~text~~`, and rejects a single tilde.
        public static let strikethroughDoubleTilde = MarkdownDocument.ParseOptions(rawValue: 1 << 14)

        /// Parses only inline content, ignoring block structure.
        public static let inlineOnly = MarkdownDocument.ParseOptions(rawValue: 1 << 18)

        /// Parses only inline content while preserving source whitespace, such as tabs and repeated spaces.
        public static let preserveWhitespace: MarkdownDocument.ParseOptions = [
            .inlineOnly,
            MarkdownDocument.ParseOptions(rawValue: 1 << 19),
        ]

        /// Allows row and column spans in GFM tables.
        public static let tableSpans = MarkdownDocument.ParseOptions(rawValue: 1 << 20)

        /// Treats a `"` in a GFM table cell as a ditto mark that repeats the cell above.
        public static let tableRowspanDitto = MarkdownDocument.ParseOptions(rawValue: 1 << 21)

        /// Enables GFM strikethrough, written as `~text~` or `~~text~~`.
        ///
        /// Without this option, `~` is ordinary text. Combine it with `.strikethroughDoubleTilde` to require exactly two tildes on each side.
        public static let strikethrough = MarkdownDocument.ParseOptions(rawValue: 1 << 22)

        /// Enables GFM task list items.
        ///
        /// A list item whose first paragraph begins with `[ ]`, `[x]`, or `[X]` followed by a space becomes an unchecked or checked task item. Without this option, the brackets stay as ordinary text in the item's first paragraph.
        public static let tasklist = MarkdownDocument.ParseOptions(rawValue: 1 << 23)

        /// Enables GFM extended autolinks.
        ///
        /// Bare URLs, such as `https://example.com` and `www.example.com`, and email addresses become `.link` nodes without requiring angle brackets around them.
        public static let gfmAutolink = MarkdownDocument.ParseOptions(rawValue: 1 << 24)

        /// Enables GFM tables.
        ///
        /// A paragraph whose first line contains `|` and whose second line is a delimiter row, such as `:---`, `---:`, or `:---:`, becomes a table with aligned columns.
        public static let tables = MarkdownDocument.ParseOptions(rawValue: 1 << 25)
    }
}
