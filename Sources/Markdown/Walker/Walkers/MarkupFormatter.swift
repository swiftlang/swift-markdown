/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

fileprivate extension Markup {
    /// The parental chain of elements from a root to this element.
    var parentalChain: [Markup] {
        var stack: [Markup] = [self]
        var current: Markup = self
        while let parent = current.parent {
            stack.append(parent)
            current = parent
        }
        return stack.reversed()
    }

    /// Return the first ancestor that matches a condition, or `nil` if there is no such ancestor.
    func firstAncestor(where ancestorMatches: (Markup) -> Bool) -> Markup? {
        var currentParent = parent
        while let current = currentParent {
            if ancestorMatches(current) {
                return current
            }
            currentParent = current.parent
        }
        return nil
    }

    /// Previous sibling of this element in its parent, or `nil` if it's the first child.
    var previousSibling: Markup? {
        guard let parent, indexInParent > 0 else {
            return nil
        }

        return parent.child(at: indexInParent - 1)
    }

    /// Whether this element is a Doxygen command.
    var isDoxygenCommand: Bool {
        return self is DoxygenDiscussion || self is DoxygenNote || self is DoxygenAbstract
            || self is DoxygenParameter || self is DoxygenReturns
    }
}

fileprivate extension String {
    /// This string, split by newline characters, dropping leading and trailing lines that are empty.
    var trimmedLineSegments: ArraySlice<Substring> {
        var splitLines = split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)[...].drop { $0.isEmpty }
        while let lastLine = splitLines.last, lastLine.isEmpty {
            splitLines = splitLines.dropLast()
        }
        return splitLines
    }
}

fileprivate extension CodeBlock {
    /// The code contents split by newline characters, dropping leading and trailing lines that are empty.
    var trimmedLineSegments: ArraySlice<Substring> {
        return code.trimmedLineSegments
    }
}

fileprivate extension HTMLBlock {
    /// The HTML contents split by newline characters, dropping leading and trailing lines that are empty.
    var trimmedLineSegments: ArraySlice<Substring> {
        return rawHTML.trimmedLineSegments
    }
}

fileprivate extension Table.Cell {
    /// Format a table cell independently as if it were its own document.
    /// The ``visitTable(_:)`` method will use this to put a formatted
    /// table together after formatting and measuring the dimensions of all
    /// of the cells.
    func formatIndependently(options: MarkupFormatter.Options) -> String {
        /// Replaces all soft and hard breaks with a single space.
        struct BreakDeleter: MarkupRewriter {
            mutating func visitSoftBreak(_ softBreak: SoftBreak) -> Markup? {
                return Text(" ")
            }

            mutating func visitLineBreak(_ softBreak: SoftBreak) -> Markup? {
                return Text(" ")
            }
        }
        // By "independently", we mean that the cell should be printed without
        // being affected by ancestral elements.
        // For example, a table might be inside a blockquote.
        // We don't want any outside context to affect the printing of the cell
        // in this method. So, we'll copy the cell out of its parent
        // before printing.

        // The syntax for table cells doesn't support newlines, unfortunately.
        // Just in case some were inserted programmatically, remove them.
        var breakDeleter = BreakDeleter()
        let detachedSelfWithoutBreaks = breakDeleter.visit(self.detachedFromParent)!

        var cellFormatter = MarkupFormatter(formattingOptions: options)
        for inline in detachedSelfWithoutBreaks.children {
            cellFormatter.visit(inline)
        }
        return cellFormatter.result
    }
}

/// Prints a `Markup` tree with formatting options.
public struct MarkupFormatter: MarkupWalker {
    /**
     Formatting options for Markdown, based on [CommonMark](https://commonmark.org).
     */
    public struct Options {
        /**
         The marker character to use for unordered lists.
         */
        public enum UnorderedListMarker: String, CaseIterable {
            /// A dash character (`-`).
            case dash = "-"

            /// A plus character (`+`).
            case plus = "+"

            /// A star/asterisk character (`*`).
            case star = "*"
        }

        /// When to use a code fence for code blocks.
        public enum UseCodeFence: String, CaseIterable {
            /// Use a code fence only when a language is present on the
            /// code block already.
            case onlyWhenLanguageIsPresent = "when-language-present"

            /// Always use a code fence.
            case always = "always"

            /// Never use a code fence.
            ///
            /// > Note: This will strip code block languages.
            case never = "never"
        }

        /// The character to use for thematic breaks.
        public enum ThematicBreakCharacter: String, CaseIterable {
            /// A dash character (`-`).
            case dash = "-"

            /// An underline/underbar character (`_`).
            case underline = "_"

            /// A star/asterisk character (`*`).
            case star = "*"
        }

        /// The character to use for emphasis and strong emphasis markers.
        public enum EmphasisMarker: String, CaseIterable {
            /// A star/asterisk character (`*`).
            case star = "*"

            /// An underline/underbar character (`_`).
            case underline = "_"
        }

        /// The preferred heading style.
        public enum PreferredHeadingStyle: String, CaseIterable {
            /// ATX-style headings.
            ///
            /// Example:
            /// ```markdown
            /// # Level-1 heading
            /// ## Level-2 heading
            /// ...
            /// ```
            case atx = "atx"

            /// Setext-style headings, limited to level 1 and 2 headings.
            ///
            /// Example:
            /// ```markdown
            /// Level-1 Heading
            /// ===============
            ///
            /// Level-2 Heading
            /// ---------------
            /// ```
            ///
            /// > Note: Setext-style headings only define syntax for heading
            /// > levels 1 and 2. To preserve structure, headings with level
            /// > 3 or above will use ATX-style headings.
            case setext = "setext"
        }

        /// The start numeral and counting style for ordered lists.
        public enum OrderedListNumerals {
            /// Use `start` for all ordered list markers, letting markdown
            /// parsers automatically increment from the `start`.
            case allSame(UInt)

            /// Print increasing ordered list marker numerals with each
            /// list item.
            case incrementing(start: UInt)
        }

        /**
         The preferred maximum line length and element for splitting  that reach that preferred limit.
         - Note: This is a *preferred* line limit, not an absolute one.
         */
        public struct PreferredLineLimit {
            /// The element to use when splitting lines that are longer than the preferred line length.
            public enum SplittingElement: String, CaseIterable {
                /**
                 Split ``Text`` elements with ``SoftBreak`` elements if a line length
                 approaches the preferred maximum length if possible.
                 */
                case softBreak = "soft-break"
                /**
                Split ``Text`` elements with ``LineBreak`` (a.k.a. *hard break*) elements if a line length
                approaches the preferred maximum length if possible.
                */
                case hardBreak = "hard-break"
            }

            /// The method for splitting lines
            public var lineSplittingElement: SplittingElement

            /// The preferred maximum line length.
            public var maxLength: Int

            /**
             Create a preferred line limit.

             - parameter maxLength: The maximum line length desired.
             - parameter splittingElement: The element used to split ``Text`` elements.
             */
            public init(maxLength: Int, breakWith splittingElement: SplittingElement) {
                precondition(maxLength > 0)
                self.maxLength = maxLength
                self.lineSplittingElement = splittingElement
            }
        }

        /// The character to use when formatting Doxygen commands.
        public enum DoxygenCommandPrefix: String, CaseIterable {
            /// Precede Doxygen commands with a backslash (`\`).
            case backslash = "\\"

            /// Precede Doxygen commands with an at-sign (`@`).
            case at = "@"
        }

        /// The spacing to use when formatting adjacent Doxygen commands.
        public enum AdjacentDoxygenCommandsSpacing: String, CaseIterable {
            /// Separate adjacent Doxygen commands with a single newline.
            case singleNewline = "single-newline"

            /// Keep a blank line between adjacent Doxygen commands creating separate paragraphs.
            case separateParagraphs = "separate-paragraphs"
        }

        // MARK: Option Properties

        var orderedListNumerals: OrderedListNumerals
        var unorderedListMarker: UnorderedListMarker
        var useCodeFence: UseCodeFence
        var defaultCodeBlockLanguage: String?
        var thematicBreakCharacter: ThematicBreakCharacter
        var thematicBreakLength: UInt
        var emphasisMarker: EmphasisMarker
        var condenseAutolinks: Bool
        var preferredHeadingStyle: PreferredHeadingStyle
        var preferredLineLimit: PreferredLineLimit?
        var customLinePrefix: String
        var doxygenCommandPrefix: DoxygenCommandPrefix
        var adjacentDoxygenCommandsSpacing: AdjacentDoxygenCommandsSpacing

        /**
         Create a set of formatting options to use when printing an element.

         - Parameters:
            - unorderedListMarker: The character to use for unordered list markers.
            - orderedListNumerals: The counting behavior and start numeral for ordered list markers.
            - useCodeFence: Decides when to use code fences on code blocks
            - defaultCodeBlockLanguage: The default language string to use when code blocks don't have a language and will be printed as fenced code blocks.
            - thematicBreakCharacter: The character to use for thematic breaks.
            - thematicBreakLength: The length of printed thematic breaks.
            - emphasisMarker: The character to use for emphasis and strong emphasis markers.
            - condenseAutolinks: Print links whose link text and destination match as autolinks, e.g. `<https://swift.org>`.
            - preferredHeadingStyle: The preferred heading style.
            - preferredLineLimit: The preferred maximum line length and method for splitting ``Text`` elements in an attempt to maintain that line length.
            - customLinePrefix: An addition prefix to print at the start of each line, useful for adding documentation comment markers.
            - doxygenCommandPrefix: The command command prefix, which defaults to ``DoxygenCommandPrefix/backslash``.
            - adjacentDoxygenCommandsSpacing: The spacing to use when formatting adjacent Doxygen commands.
         */
        public init(unorderedListMarker: UnorderedListMarker = .dash,
                    orderedListNumerals: OrderedListNumerals = .allSame(1),
                    useCodeFence: UseCodeFence = .always,
                    defaultCodeBlockLanguage: String? = nil,
                    thematicBreakCharacter: ThematicBreakCharacter = .dash,
                    thematicBreakLength: UInt = 5,
                    emphasisMarker: EmphasisMarker = .star,
                    condenseAutolinks: Bool = true,
                    preferredHeadingStyle: PreferredHeadingStyle = .atx,
                    preferredLineLimit: PreferredLineLimit? = nil,
                    customLinePrefix: String = "",
                    doxygenCommandPrefix: DoxygenCommandPrefix = .backslash,
                    adjacentDoxygenCommandsSpacing: AdjacentDoxygenCommandsSpacing = .singleNewline) {
            self.unorderedListMarker = unorderedListMarker
            self.orderedListNumerals = orderedListNumerals
            self.useCodeFence = useCodeFence
            self.defaultCodeBlockLanguage = defaultCodeBlockLanguage
            self.thematicBreakCharacter = thematicBreakCharacter
            self.emphasisMarker = emphasisMarker
            self.condenseAutolinks = condenseAutolinks
            self.preferredHeadingStyle = preferredHeadingStyle
            self.preferredLineLimit = preferredLineLimit
            // Per CommonMark spec, thematic breaks must be at least
            // three characters long.
            self.thematicBreakLength = max(3, thematicBreakLength)
            self.customLinePrefix = customLinePrefix
            self.doxygenCommandPrefix = doxygenCommandPrefix
            self.adjacentDoxygenCommandsSpacing = adjacentDoxygenCommandsSpacing
        }

        /// The default set of formatting options.
        public static let `default` = Options()
    }

    /// Formatting options to use while printing.
    public var formattingOptions: Options

    /// The formatted result.
    public private(set) var result = ""
    // > Warning! Do not directly append to ``result`` in any method except:
    // > - ``print(_:for:)``
    // > - ``addressPendingNewlines(for:)``
    // >
    // > Be careful to update ``state`` when appending to ``result``.
    // >
    // > Use ``print(_:for:)`` for all general purpose printing. This
    // > makes sure pending newlines, indentation, and prefixes are
    // > consistently addressed.

    /// Create a `MarkupPrinter` with formatting options.
    public init(formattingOptions: Options = .default) {
        self.formattingOptions = formattingOptions
    }

    // MARK: Formatter State

    /// The state of the formatter, excluding the formatted result so that
    /// unnecessary String copies aren't made.
    ///
    /// Since the formatted result is only ever appended to, we can use
    /// prior state to erase what was printed since the last state save.
    struct State {
        /// The current length of the formatted result.
        ///
        /// This is used to undo speculative prints in certain situations.
        var currentLength = 0

        /// The number of newlines waiting to be printed before any other
        /// content is printed.
        var queuedNewlines = 0

        /// The number of empty lines up to now.
        var newlineStreak = 0

        /// The length of the last line.
        var lastLineLength = 0

        /// The line number of the most recently printed content.
        ///
        /// This is updated in `addressPendingNewlines(for:)` when line breaks are printed.
        var lineNumber = 0

        /// The "effective" line number, taking into account any queued newlines which have not
        /// been printed.
        ///
        /// This property allows line number comparisons between different formatter states to
        /// accommodate queued soft line breaks as well as printed content.
        var effectiveLineNumber: Int {
            lineNumber + queuedNewlines
        }
    }

    /// The state of the formatter.
    var state = State()

    // MARK: Formatter Utilities

    /// True if the current line length is over the preferred line limit.
    var isOverPreferredLineLimit: Bool {
        guard let lineLimit = formattingOptions.preferredLineLimit else {
            return false
        }
        return state.lastLineLength >= lineLimit.maxLength
    }

    /**
     Given a parental chain, returns the line prefix needed when printing
     a new line while visiting a given element.

     For example, in the following hierarchy:

     ```
     Document
     └─ BlockQuote
     ```

     Each new line in the block quote needs a "`> `" line prefix before printing
     anything else inside it.

     To refine this example, say we have this hierarchy:

     ```
     Document
     └─ BlockQuote
        └─ Paragraph
           ├─ Text "A"
           ├─ SoftBreak
           └─ Text "blockquote"
     ```

     When we go to print `Text("A")`, we need to start with the line prefix
     "`> `":

     ```
     > A
     ```

     We see the `SoftBreak` and queue up a newline.
     Moving to `Text("blockquote")`, we address the queue newline first:

     ```
     > A
     >
     ```

     and then print its contents.

     ```
     > A
     > blockquote.
     ```

     This should work with multiple nesting.
     */
    func linePrefix(for element: Markup) -> String {
        var prefix = formattingOptions.customLinePrefix
        var unorderedListCount = 0
        var orderedListCount = 0
        for element in element.parentalChain {
            if element is BlockQuote {
                prefix += "> "
            } else if element is UnorderedList {
                if unorderedListCount > 0 {
                    prefix += "  "
                }
                unorderedListCount += 1
            } else if element is OrderedList {
                if orderedListCount > 0 {
                    prefix += "   "
                }
                orderedListCount += 1
            } else if !(element is ListItem),
                let parentListItem = element.parent as? ListItem {
                /*
                 Align contents with list item markers.

                 Example, unordered lists:

                 - First line
                   Second line, aligned.

                 Example, ordered lists:

                 1. First line
                    Second line, aligned.
                 1000. First line
                       Second line, aligned.
                 */

                if parentListItem.parent is UnorderedList {
                    // Unordered list markers are of fixed length.
                    prefix += "  "
                } else if let numeralPrefix = numeralPrefix(for: parentListItem) {
                    prefix += String(repeating: " ", count: numeralPrefix.count)
                }
            }
            if element.parent is BlockDirective {
                prefix += "    "
            }
        }
        return prefix
    }

    /// Queue a newline for printing, which will be lazily printed the next
    /// time any non-newline characters are printed.
    mutating func queueNewline(count: Int = 1) {
        state.queuedNewlines += count
    }

    /// Address pending newlines while printing an element.
    ///
    /// > Note: When printing a newline, each kind of element may require
    /// > a prefix on each line in order to continue printing its content,
    /// > such as block quotes, which require a `>` character on each line.
    ///
    /// - SeeAlso: ``linePrefix(for:)``.
    mutating func addressPendingNewlines(for element: Markup) {
        guard state.queuedNewlines > 0 else {
            // Return early to prevent current line length from
            // getting modified below.
            return
        }

        let prefix = linePrefix(for: element)

        for _ in 0..<state.queuedNewlines {
            result += "\n"
            state.currentLength += 1
            result += prefix
            state.currentLength += prefix.count
            state.lineNumber += 1
        }

        state.newlineStreak += state.queuedNewlines
        state.queuedNewlines = 0
        state.lastLineLength = prefix.count
    }

    /// Make sure that there are at least `count` newline characters since
    /// the last printed element.
    mutating func ensurePrecedingNewlineCount(atLeast count: Int) {
        let emptyLinesSinceLastElement = state.newlineStreak + state.queuedNewlines
        let newlinesNeeded = max(0, count - emptyLinesSinceLastElement)
        queueNewline(count: newlinesNeeded)
    }

    /// Get the numeral prefix for a list item if its parent is an ordered list.
    func numeralPrefix(for listItem: ListItem) -> String? {
        guard listItem.parent is OrderedList else {
            return nil
        }
        let numeral: UInt
        // FIXME: allow `orderedListNumerals` to defer to the user-authored starting index (#76, rdar://99970544)
        switch formattingOptions.orderedListNumerals {
        case let .allSame(n):
            numeral = n
        case let .incrementing(start):
            numeral = start + UInt(listItem.indexInParent)
        }
        return "\(numeral). "
    }

    /// Address any pending newlines and print raw text while visiting an element.
    mutating func print<S: StringProtocol>(_ rawText: S, for element: Markup) {
        addressPendingNewlines(for: element)

        // If this is the first time we're printing something, we can't
        // use newlines and ``addressPendingNewlines(for:)` to drive
        // printing a prefix, so add the prefix manually just this once.
        if result.isEmpty {
            let prefix = linePrefix(for: element)
            result += prefix
            state.currentLength += prefix.count
            state.lastLineLength += prefix.count
        }

        result += rawText
        state.currentLength += rawText.count
        state.lastLineLength += rawText.count
        state.newlineStreak = 0
    }

    /// Print raw text while visiting an element, wrapping automatically with
    /// soft or hard line breaks.
    ///
    /// If there is no preferred line limit set in the formatting options,
    /// ``print(_:for:)`` as usual without automatic wrapping.
    mutating func softWrapPrint(_ string: String, for element: InlineMarkup) {
        guard let lineLimit = formattingOptions.preferredLineLimit else {
            print(string, for: element)
            return
        }

        // Headings may not have soft breaks.
        guard element.firstAncestor(where: { $0 is Heading }) == nil else {
            print(string, for: element)
            return
        }

        let words = string.components(separatedBy: CharacterSet(charactersIn: " \t"))[...]

        /// Hard line breaks in Markdown require two spaces before the newline; soft breaks require none.
        let breakSuffix: String
        switch lineLimit.lineSplittingElement {
        case .hardBreak:
            breakSuffix = "  "
        case .softBreak:
            breakSuffix = ""
        }

        var wordsThisLine = 0
        for index in words.indices {
            let word = words[index]

            if index == words.startIndex && wordsThisLine == 0 {
                // Always print the first word if it's at the start of a line.
                // A break won't help here and could actually hurt by
                // unintentionally starting a new paragraph.
                // However, there is one exception:
                // we might already be right at the edge of a line when
                // this method was called.
                if state.lastLineLength + word.count >= lineLimit.maxLength {
                    queueNewline()
                }
                print(word, for: element)
                wordsThisLine += 1
                continue
            }

            if state.lastLineLength + word.count + breakSuffix.count + 1 >= lineLimit.maxLength {
                print(breakSuffix, for: element)
                queueNewline()
                wordsThisLine = 0
            }

            // Insert a space between words.
            if wordsThisLine > 0 {
                print(" ", for: element)
            }

            // Finally, print the word.
            print(word, for: element)
            wordsThisLine += 1
        }
    }

    /// Restore state to a previous state, trimming off what was printed since then.
    mutating func restoreState(to previousState: State) {
        result.removeLast(state.currentLength - previousState.currentLength)
        state = previousState
    }

    // MARK: Formatter Walker Methods

    public func defaultVisit(_ markup: Markup) {
        fatalError("Formatter not implemented for \(type(of: markup))")
    }

    public mutating func visitDocument(_ document: Document) {
        descendInto(document)
    }

    public mutating func visitParagraph(_ paragraph: Paragraph) {
        if paragraph.indexInParent > 0 {
            ensurePrecedingNewlineCount(atLeast: 2)
        }
        descendInto(paragraph)
    }

    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        if codeBlock.indexInParent > 0 {
            ensurePrecedingNewlineCount(atLeast: 2)
        }

        let lines = codeBlock.trimmedLineSegments

        let shouldUseFence: Bool

        switch formattingOptions.useCodeFence {
        case .never:
            shouldUseFence = false
        case .always:
            shouldUseFence = true
        case .onlyWhenLanguageIsPresent:
            shouldUseFence = codeBlock.language != nil
        }

        if shouldUseFence {
            print("```", for: codeBlock)
            print(codeBlock.language ?? formattingOptions.defaultCodeBlockLanguage ?? "", for: codeBlock)
            queueNewline()
        }

        for index in lines.indices {
            let line = lines[index]

            if index != lines.startIndex {
                queueNewline()
            }

            let indentation = shouldUseFence ? "" : "    "
            print(indentation + line, for: codeBlock)
        }

        if shouldUseFence {
            queueNewline()
            print("```", for: codeBlock)
        }
    }

    public mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        if let parent = blockQuote.parent {
            if parent is BlockQuote {
                queueNewline()
            } else if blockQuote.indexInParent > 0 {
                queueNewline()
                addressPendingNewlines(for: parent)
                queueNewline()
            }
        }
        descendInto(blockQuote)
    }

    mutating public func visitUnorderedList(_ unorderedList: UnorderedList) {
        if unorderedList.indexInParent > 0 && !(unorderedList.parent?.parent is ListItemContainer) {
            ensurePrecedingNewlineCount(atLeast: 2)
        }
        descendInto(unorderedList)
    }

    mutating public func visitOrderedList(_ orderedList: OrderedList) {
        if orderedList.indexInParent > 0 && !(orderedList.parent?.parent is ListItemContainer) {
            ensurePrecedingNewlineCount(atLeast: 2)
        }
        descendInto(orderedList)
    }

    public mutating func visitHTMLBlock(_ html: HTMLBlock) {
        if html.indexInParent > 0 {
            ensurePrecedingNewlineCount(atLeast: 2)
        }
        for lineSegment in html.trimmedLineSegments {
            print(lineSegment, for: html)
            queueNewline()
        }
    }

    public mutating func visitListItem(_ listItem: ListItem) {
        if listItem.indexInParent > 0 || listItem.parent?.indexInParent ?? 0 > 0 {
            ensurePrecedingNewlineCount(atLeast: 1)
        }

        let checkbox = listItem.checkbox.map {
            switch $0 {
            case .checked: return "[x] "
            case .unchecked: return "[ ] "
            }
        } ?? ""

        if listItem.parent is UnorderedList {
            print("\(formattingOptions.unorderedListMarker.rawValue) \(checkbox)", for: listItem)
        } else if let numeralPrefix = numeralPrefix(for: listItem) {
            print("\(numeralPrefix)\(checkbox)", for: listItem)
        }
        descendInto(listItem)
    }

    public mutating func visitHeading(_ heading: Heading) {
        if heading.indexInParent > 0 {
            ensurePrecedingNewlineCount(atLeast: 2)
        }

        if case .setext = formattingOptions.preferredHeadingStyle,
            heading.level < 3 /* See fatalError below. */ {
            // Print a Setext-style heading.
            descendInto(heading)
            queueNewline()

            let headingMarker: String
            switch heading.level {
            case 1:
                headingMarker = "="
            case 2:
                headingMarker = "-"
            default:
                fatalError("Unexpected heading level \(heading.level) while formatting for setext-style heading")
            }
            print(String(repeating: headingMarker, count: state.lastLineLength), for: heading)
        } else {
            // Print an ATX-style heading.
            print(String(repeating: "#", count: heading.level), for: heading)
            print(" ", for: heading)
            descendInto(heading)
        }
    }

    public mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        if thematicBreak.indexInParent > 0 {
            ensurePrecedingNewlineCount(atLeast: 2)
        }
        let breakString = String(repeating: formattingOptions.thematicBreakCharacter.rawValue,
                                 count: Int(formattingOptions.thematicBreakLength))
        print(breakString, for: thematicBreak)
    }

    public mutating func visitInlineCode(_ inlineCode: InlineCode) {
        let savedState = state
        softWrapPrint("`\(inlineCode.code)`", for: inlineCode)

        // Splitting inline code elements is allowed if it contains spaces.
        // If printing with automatic wrapping still put us over the line,
        // prefer to print it on the next line to give as much opportunity
        // to keep the contents on one line.
        if inlineCode.indexInParent > 0 && (isOverPreferredLineLimit || state.effectiveLineNumber > savedState.effectiveLineNumber) {
            restoreState(to: savedState)
            queueNewline()
            softWrapPrint("`\(inlineCode.code)`", for: inlineCode)
        }
    }

    public mutating func visitEmphasis(_ emphasis: Emphasis) {
        print(formattingOptions.emphasisMarker.rawValue, for: emphasis)
        descendInto(emphasis)
        print(formattingOptions.emphasisMarker.rawValue, for: emphasis)
    }

    public mutating func visitImage(_ image: Image) {
        let savedState = state
        func printImage() {
            print("![", for: image)
            descendInto(image)
            print("](", for: image)
            print(image.source ?? "", for: image)
            if let title = image.title {
                print(" \"\(title)\"", for: image)
            }
            print(")", for: image)
        }

        printImage()

        // Image elements' source URLs can't be split. If wrapping the alt text
        // of an image still put us over the line, prefer to print it on the
        // next line to give as much opportunity to keep the alt text contents on one line.
        if image.indexInParent > 0 && (isOverPreferredLineLimit || state.effectiveLineNumber > savedState.effectiveLineNumber) {
            restoreState(to: savedState)
            queueNewline()
            printImage()
        }
    }

    public mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        print(inlineHTML.rawHTML, for: inlineHTML)
    }

    public mutating func visitLineBreak(_ lineBreak: LineBreak) {
        print("  ", for: lineBreak)
        queueNewline()
    }

    public mutating func visitLink(_ link: Link) {
        let savedState = state
        if formattingOptions.condenseAutolinks,
           link.isAutolink,
           let destination = link.destination {
            print("<\(destination)>", for: link)
        } else {
            func printRegularLink() {
                // Print as a regular link
                print("[", for: link)
                descendInto(link)
                print("](", for: link)
                print(link.destination ?? "", for: link)
                print(")", for: link)
            }

            printRegularLink()

            // Link elements' destination URLs can't be split. If wrapping the link text
            // of a link still put us over the line, prefer to print it on the
            // next line to give as much opportunity to keep the link text contents on one line.
            if link.indexInParent > 0 && (isOverPreferredLineLimit || state.effectiveLineNumber > savedState.effectiveLineNumber) {
                restoreState(to: savedState)
                queueNewline()
                printRegularLink()
            }
        }
    }

    public mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        queueNewline()
    }

    public mutating func visitStrong(_ strong: Strong) {
        print(String(repeating: formattingOptions.emphasisMarker.rawValue, count: 2), for: strong)
        descendInto(strong)
        print(String(repeating: formattingOptions.emphasisMarker.rawValue, count: 2), for: strong)
    }

    public mutating func visitText(_ text: Text) {
        // This is where most of the wrapping occurs.
        // Text elements have the most flexible content of all, not containing
        // any special Markdown syntax or punctuation.
        // We can do this because the model differentiates between real Text
        // content and string-like data, such as URLs.
        softWrapPrint(text.string, for: text)
    }

    public mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        print("~", for: strikethrough)
        descendInto(strikethrough)
        print("~", for: strikethrough)
    }

    /// Format a table as an indivisible unit.
    ///
    /// Because tables likely print multiple cells of inline content next
    /// to each other on the same line, we're breaking with the pattern
    /// a little bit here and not descending into the substructure of a table
    /// automatically in this ``MarkupFormatter``. We'll handle all of the
    /// cells right here.
    public mutating func visitTable(_ table: Table) {
        if table.indexInParent > 0 {
            ensurePrecedingNewlineCount(atLeast: 2)
        }
        // The general strategy is to print each table cell completely
        // independently, measuring each of their dimensions, and then expanding
        // them so that all cells in the same column have the same width
        // by adding trailing spaces accordingly.

        // Once that's done, we should be able to go through and print
        // the cells in a straightforward way by just adding the pipes `|` and
        // delimiter row. Let's go!

        /// The column count of all of the printed rows.
        ///
        /// Markdown parsers like CommonMark drop extraneous columns and we
        /// want to prevent information loss when printing, so we'll expand
        /// all of the rows to have the same number of columns.
        let uniformColumnCount = table.maxColumnCount

        /// A copy of this formatter's options to prevent capture of `self`
        /// in some `map` calls below.
        let cellFormattingOptions = formattingOptions

        // First, format each cell independently.

        /// All of the independently formatted head cells' text, adding cells
        /// as needed to meet the uniform `uniformColumnCount`.
        let headCellTexts = Array(table.head.cells.map {
            $0.formatIndependently(options: cellFormattingOptions)
        }).ensuringCount(atLeast: uniformColumnCount, filler: "")

        /// All of the column-span values from the head cells, adding cells as
        /// needed to meet the uniform `uniformColumnCount`.
        let headCellSpans = Array(table.head.cells.map {
            $0.colspan
        }).ensuringCount(atLeast: uniformColumnCount, filler: 1)

        /// All of the independently formatted body cells' text by row, adding
        /// cells to each row to meet the `uniformColumnCount`.
        let bodyRowTexts = Array(table.body.rows.map { row -> [String] in
            return Array(row.cells.map {
                if $0.rowspan == 0 {
                    // If this cell is being spanned over, replace its text
                    // (which should be the empty string anyway) with the
                    // rowspan marker.
                    return "^"
                } else {
                    return $0.formatIndependently(options: cellFormattingOptions)
                }
            }).ensuringCount(atLeast: uniformColumnCount,
                             filler: "")
        })

        /// All of the column- and row-span information for the body cells,
        /// cells to each row to meet the `uniformColumnCount`.
        let bodyRowSpans = Array(table.body.rows.map { row in
            return Array(row.cells.map {
                (colspan: $0.colspan, rowspan: $0.rowspan)
            }).ensuringCount(atLeast: uniformColumnCount,
                             filler: (colspan: 1, rowspan: 1))
        })

        // Next, calculate the maximum width of each column.

        /// The column alignments of the table, filled out to `uniformColumnCount`.
        let columnAlignments = table.columnAlignments
            .ensuringCount(atLeast: uniformColumnCount,
                           filler: nil)

        // Start with the column alignments. The following are the minimum to
        // specify each column alignment in markdown:
        // - left: `:-`; can be expanded to `:-----` etc.
        // - right: `-:`; can be expanded to `-----:` etc.
        // - center: `:-:`; can be expanded to `:------:` etc.
        // - nil: `-`; can be expanded to `-------` etc.

        /// The final widths of each column in characters.
        var finalColumnWidths = columnAlignments.map { alignment -> Int in
            guard let alignment = alignment else {
                return 0
            }
            switch alignment {
            case .left,
                 .right:
                return 2
            case .center:
                return 3
            }
        }

        precondition(finalColumnWidths.count == headCellTexts.count)

        // Update max column widths from each header cell.
        finalColumnWidths = zip(finalColumnWidths, headCellTexts).map {
            return max($0, $1.count)
        }

        // Update max column widths from each cell of each row in the body.
        for row in bodyRowTexts {
            finalColumnWidths.ensureCount(atLeast: row.count, filler: 0)
            for (i, cellText) in row.enumerated() {
                finalColumnWidths[i] = max(finalColumnWidths[i],
                                           cellText.count)
            }
        }

        /// Calculate the width of the given column and colspan.
        ///
        /// This adds up the appropriate column widths based on the given column span, including
        /// the default span of 1, where it will only return the `finalColumnWidths` value for the
        /// given `column`.
        func columnWidth(column: Int, colspan: Int) -> Int {
            finalColumnWidths.dropFirst(column).prefix(colspan).reduce(0, +)
        }

        // We now know the width that each printed column will be.

        /// Each of the header cells expanded to the right dimensions by
        /// extending each line with spaces to fit the uniform column width.
        let expandedHeaderCellTexts = (0..<uniformColumnCount)
            .map { column -> String in
                let colspan = headCellSpans[column]
                if colspan == 0 {
                    // If this cell is being spanned over, collapse it so it
                    // can be filled with the spanning cell.
                    return ""
                } else {
                    let minLineLength = columnWidth(column: column, colspan: Int(colspan))
                    return headCellTexts[column]
                        .ensuringCount(atLeast: minLineLength, filler: " ")
                }
            }

        /// Rendered delimter row cells with the correct width.
        let delimiterRowCellTexts = columnAlignments.enumerated()
            .map { (column, alignment) -> String in
                let columnWidth = finalColumnWidths[column]
                guard let alignment = alignment else {
                    return String(repeating: "-", count: columnWidth)
                }
                switch alignment {
                case .left:
                    let dashes = String(repeating: "-", count: columnWidth - 1)
                    return ":\(dashes)"
                case .right:
                    let dashes = String(repeating: "-", count: columnWidth - 1)
                    return "\(dashes):"
                case .center:
                    let dashes = String(repeating: "-", count: columnWidth - 2)
                    return ":\(dashes):"
                }
        }

        /// Each of the body cells expanded to the right dimensions by
        /// extending each line with spaces to fit the uniform column width
        /// appropriately for their row and column.
        let expandedBodyRowTexts = bodyRowTexts.enumerated()
            .map { (row, rowCellTexts) -> [String] in
                let rowSpans = bodyRowSpans[row]
                return (0..<uniformColumnCount).map { column -> String in
                    let colspan = rowSpans[column].colspan
                    if colspan == 0 {
                        // If this cell is being spanned over, collapse it so it
                        // can be filled with the spanning cell.
                        return ""
                    } else {
                        let minLineLength = columnWidth(column: column, colspan: Int(colspan))
                        return rowCellTexts[column]
                            .ensuringCount(atLeast: minLineLength, filler: " ")
                    }
                }
            }

        // Print the expanded head cells.
        print("|", for: table.head)
        print(expandedHeaderCellTexts.joined(separator: "|"), for: table.head)
        print("|", for: table.head)
        queueNewline()

        // Print the delimiter row.
        print("|", for: table.head)
        print(delimiterRowCellTexts.joined(separator: "|"), for: table.head)
        print("|", for: table.head)
        queueNewline()

        // Print the body rows.
        for (row, bodyRow) in expandedBodyRowTexts.enumerated() {
            print("|", for: table.body.child(at: row)!)
            print(bodyRow.joined(separator: "|"), for: table.body.child(at: row)!)
            print("|", for: table.body.child(at: row)!)
            queueNewline()
        }
    }

    /// See ``MarkupFormatter/visitTable(_:)-61rlp`` for more information.
    public mutating func visitTableHead(_ tableHead: Table.Head) {
        fatalError("Do not call \(#function) directly; markdown tables must be formatted as a single unit. Call `visitTable` on the parent table")
    }

    /// See ``MarkupFormatter/visitTable(_:)-61rlp`` for more information.
    public mutating func visitTableBody(_ tableBody: Table.Body) {
        fatalError("Do not call \(#function) directly; markdown tables must be formatted as a single unit. Call `visitTable` on the parent table")
    }

    /// See ``MarkupFormatter/visitTable(_:)-61rlp`` for more information.
    public mutating func visitTableRow(_ tableRow: Table.Row) {
        fatalError("Do not call \(#function) directly; markdown tables must be formatted as a single unit. Call `visitTable` on the parent table")
    }

    /// See ``MarkupFormatter/visitTable(_:)-61rlp`` for more information.
    public mutating func visitTableCell(_ tableCell: Table.Cell) {
        fatalError("Do not call \(#function) directly; markdown tables must be formatted as a single unit. Call `visitTable` on the parent table")
    }

    public mutating func visitBlockDirective(_ blockDirective: BlockDirective) {
        if blockDirective.indexInParent > 0 {
            ensurePrecedingNewlineCount(atLeast: 2)
        }
        print("@", for: blockDirective)
        print(blockDirective.name, for: blockDirective)

        if !blockDirective.argumentText.segments.isEmpty {
            print("(", for: blockDirective)

            for (i, segment) in blockDirective.argumentText.segments.enumerated() {
                if i != 0 {
                    queueNewline()
                }
                print(segment.trimmedText, for: blockDirective)
            }

            print(")", for: blockDirective)
        }

        if blockDirective.childCount > 0 {
            print(" {", for: blockDirective)
            queueNewline()
        }

        descendInto(blockDirective)

        if blockDirective.childCount > 0 {
            queueNewline()
            print("}", for: blockDirective)
        }
    }

    public mutating func visitSymbolLink(_ symbolLink: SymbolLink) {
        print("``", for: symbolLink)
        print(symbolLink.destination ?? "", for: symbolLink)
        print("``", for: symbolLink)
    }

    public mutating func visitInlineAttributes(_ attributes: InlineAttributes) {
        let savedState = state
        func printInlineAttributes() {
            print("^[", for: attributes)
            descendInto(attributes)
            print("](", for: attributes)
            print(attributes.attributes, for: attributes)
            print(")", for: attributes)
        }

        printInlineAttributes()

        // Inline attributes *can* have their key-value pairs split across multiple
        // lines as they are formatted as JSON5, however formatting the output as such
        // gets into the realm of JSON formatting which might be out of scope of
        // this formatter. Therefore if exceeded, prefer to print it on the next
        // line to give as much opportunity to keep the attributes on one line.
        if attributes.indexInParent > 0 && (isOverPreferredLineLimit || state.effectiveLineNumber > savedState.effectiveLineNumber) {
            restoreState(to: savedState)
            queueNewline()
            printInlineAttributes()
        }
    }

    private mutating func printDoxygenStart(_ name: String, for element: Markup) {
        print(formattingOptions.doxygenCommandPrefix.rawValue + name + " ", for: element)
    }

    private mutating func ensureDoxygenCommandPrecedingNewline(for element: Markup) {
        guard let previousSibling = element.previousSibling else {
            return
        }

        guard formattingOptions.adjacentDoxygenCommandsSpacing == .singleNewline else {
            ensurePrecedingNewlineCount(atLeast: 2)
            return
        }

        let newlineCount = previousSibling.isDoxygenCommand ? 1 : 2
        ensurePrecedingNewlineCount(atLeast: newlineCount)
    }

    public mutating func visitDoxygenDiscussion(_ doxygenDiscussion: DoxygenDiscussion) {
        ensureDoxygenCommandPrecedingNewline(for: doxygenDiscussion)
        printDoxygenStart("discussion", for: doxygenDiscussion)
        descendInto(doxygenDiscussion)
    }

    public mutating func visitDoxygenAbstract(_ doxygenAbstract: DoxygenAbstract) {
        ensureDoxygenCommandPrecedingNewline(for: doxygenAbstract)
        printDoxygenStart("abstract", for: doxygenAbstract)
        descendInto(doxygenAbstract)
    }

    public mutating func visitDoxygenNote(_ doxygenNote: DoxygenNote) {
        ensureDoxygenCommandPrecedingNewline(for: doxygenNote)
        printDoxygenStart("note", for: doxygenNote)
        descendInto(doxygenNote)
    }

    public mutating func visitDoxygenParameter(_ doxygenParam: DoxygenParameter) {
        ensureDoxygenCommandPrecedingNewline(for: doxygenParam)
        printDoxygenStart("param", for: doxygenParam)
        print("\(doxygenParam.name) ", for: doxygenParam)
        descendInto(doxygenParam)
    }

    public mutating func visitDoxygenReturns(_ doxygenReturns: DoxygenReturns) {
        ensureDoxygenCommandPrecedingNewline(for: doxygenReturns)
        // FIXME: store the actual command name used in the original markup
        printDoxygenStart("returns", for: doxygenReturns)
        descendInto(doxygenReturns)
    }

}
