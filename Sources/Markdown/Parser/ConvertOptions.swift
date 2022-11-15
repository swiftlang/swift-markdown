/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import cmark_gfm

/// Options to use when converting Markdown.
public struct ConvertOptions {
    public let parseOptions: ParseOptions
    public let commonmarkOptions: CommonmarkOptions
    public let commonmarkExtensions: [String]

    public init(parseOptions: ParseOptions, commonmarkOptions: CommonmarkOptions, extensions: [String]) {
        self.parseOptions = parseOptions
        self.commonmarkOptions = commonmarkOptions
        self.commonmarkExtensions = extensions
    }

    public init(fromParseOptions options: ParseOptions) {
        var commonmarkOptions = ConvertOptions.defaultCommonmarkOptions
        if options.contains(.disableSmartOpts) {
            commonmarkOptions.remove(.smart)
        }
        self.init(
            parseOptions: options,
            commonmarkOptions: commonmarkOptions,
            extensions: ConvertOptions.defaultCommonmarkExtensions
        )
    }

    public init() {
        self.init(fromParseOptions: ConvertOptions.defaultParseOptions)
    }

    public static let defaultParseOptions: ParseOptions = []
    public static let defaultCommonmarkOptions: CommonmarkOptions = [
        .smart,
        .tableSpans,
    ]
    public static let defaultCommonmarkExtensions: [String] = [
        "table",
        "strikethrough",
        "tasklist",
    ]
}

/// Options given to the Commonmark converter.
public struct CommonmarkOptions: OptionSet {
    public var rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// The default Commonmark behavior, no special options.
    public static let `default` = CommonmarkOptions(rawValue: CMARK_OPT_DEFAULT)

    /// Include a `data-sourcepos` element on all block elements.
    public static let sourcepos = CommonmarkOptions(rawValue: CMARK_OPT_SOURCEPOS)

    /// Render `softbreak` elements as hard line breaks.
    public static let hardBreaks = CommonmarkOptions(rawValue: CMARK_OPT_HARDBREAKS)

    /// Render raw HTML and unsafe links.
    ///
    /// Unsafe links are `javascript:`, `vbscript:`, `file:`, and
    /// `data:`, except for `image/png`, `image/gif`, `image/jpeg`
    /// or `image/webp` MIME types. Without this option, raw HTML
    /// is replaced by a placeholder HTML comment. Unsafe links
    /// are replaced by empty strings.
    public static let unsafe = CommonmarkOptions(rawValue: CMARK_OPT_UNSAFE)

    /// Render `softbreak` elements as spaces.
    public static let noBreaks = CommonmarkOptions(rawValue: CMARK_OPT_NOBREAKS)

    /// Validate UTF-8 in the input before parsing, replacing illegal
    /// sequences with the replacement character `U+FFFD`.
    public static let validateUtf8 = CommonmarkOptions(rawValue: CMARK_OPT_VALIDATE_UTF8)

    /// Convert straight quotes to curly, `---` to em dashes, `--` to en dashes.
    public static let smart = CommonmarkOptions(rawValue: CMARK_OPT_SMART)

    /// Use GitHub-style `<pre lang="x">` tags for code blocks instead of
    /// `<pre><code class="language-x">`.
    public static let githubPreLang = CommonmarkOptions(rawValue: CMARK_OPT_GITHUB_PRE_LANG)

    /// Be liberal in interpreting inline HTML tags.
    public static let liberalHtmlTag = CommonmarkOptions(rawValue: CMARK_OPT_LIBERAL_HTML_TAG)

    /// Parse footnotes.
    public static let footnotes = CommonmarkOptions(rawValue: CMARK_OPT_FOOTNOTES)

    /// Only parse strikethroughs if surrounded by exactly 2 tildes.
    ///
    /// Strikethroughs are still only parsed when the `"strikethrough"`
    /// extension is enabled.
    public static let strikethroughDoubleTilde = CommonmarkOptions(rawValue: CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE)

    /// Use style attributes to align table cells instead of align attributes.
    public static let tablePreferStyleAttributes = CommonmarkOptions(rawValue: CMARK_OPT_TABLE_PREFER_STYLE_ATTRIBUTES)

    /// Include the remainder of the info string in code blocks in
    /// a separate attribute.
    public static let fullInfoString = CommonmarkOptions(rawValue: CMARK_OPT_FULL_INFO_STRING)

    /// Parse only inline markdown directives. Block directives will not be
    /// parsed (their literal representations will remain in the output).
    public static let inlineOnly = CommonmarkOptions(rawValue: CMARK_OPT_INLINE_ONLY)

    /// Parse the markdown input without removing preceding/trailing whitespace and
    /// without converting newline characters to breaks.
    ///
    /// Using this option also enables the `CMARK_OPT_INLINE_ONLY` option.
    // FIXME: the original `CMARK_OPT_PRESERVE_WHITESPACE` isn't available to the swift compiler?
    public static let preserveWhitespace = CommonmarkOptions(rawValue: (1 << 19) | CMARK_OPT_INLINE_ONLY)

    /// Enable the row- and column-span syntax in the tables extension.
    public static let tableSpans = CommonmarkOptions(rawValue: CMARK_OPT_TABLE_SPANS)

    /// Use a "ditto mark" (`"`) instead of a caret (`^`) to indicate row-spans in the tables extension.
    public static let tableRowspanDitto = CommonmarkOptions(rawValue: CMARK_OPT_TABLE_ROWSPAN_DITTO)
}
