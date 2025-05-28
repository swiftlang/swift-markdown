/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

struct PendingBlockDirective {
    enum ParseState {
        /// A left parenthesis `(` is expected to signal the start of
        /// a directive's argument text.
        case argumentsStart

        /// Some argument text is expected.
        case argumentsText

        /// A right parenthesis `)` is expected to signal the end of
        /// a directive's argument text.
        case argumentsEnd

        /// A left curly bracket `{` is expected to signal the start of a
        /// directive's child content.
        case contentsStart

        /// Directive's child content.
        case contents

        /// A right curly bracket `}` is expected to signal the end of a
        /// directive's child content.
        case contentsEnd

        /// There is no more parsing to be done; the container is closed.
        case done
    }

    /// The number of columns of indentation to adjust this directive's content, to ensure CommonMark doesn't accidentally
    /// treat the contents as indented code blocks.
    var indentationColumnCount: Int {
        return innerIndentationColumnCount ?? atIndentationColumnCount
    }

    /// The number of columns of indentation that were before the `@`.
    var atIndentationColumnCount: Int
    
    /// The number of columns of indentation that were before the first line inside the directive.
    var innerIndentationColumnCount: Int?

    /// The source location of the `@` block directive opening marker.
    var atLocation: SourceLocation

    /// The source location of the first character of the directive's name
    var nameLocation: SourceLocation

    /// The name of the directive
    var name: Substring

    /// Segments of lines that contribute to the text that will become
    /// a block directive's arguments
    var argumentsText = [TrimmedLine.Lex]()

    /// The state of scanning argument text.
    var parseState = ParseState.argumentsStart

    /// The location of the last character accepted into the block directive.
    var endLocation: SourceLocation

    /// The pending line of the block directive
    var pendingLine: TrimmedLine?

    /// `true` if the block directive container is expecting child content,
    /// i.e. it has parsed an opening curly brace `{`.
    var isAwaitingChildContent: Bool {
        switch parseState {
        case .contents, .contentsEnd:
            return true
        default:
            return false
        }
    }

    /// If this is the first line of content for this block directive, adjusts the indentation offset to account for
    /// the given line's indentation.
    mutating func updateIndentation(for line: TrimmedLine) {
        if innerIndentationColumnCount == nil, !line.isEmptyOrAllWhitespace {
            innerIndentationColumnCount = line.indentationColumnCount
        }
    }

    /// Continue parsing from the `argumentsStart` state.
    @discardableResult
    mutating func parseArgumentsStart(from line: TrimmedLine) -> Bool {
        precondition(parseState == .argumentsStart)

        var line = line
        line.lexWhitespace()

        if line.lex("(") != nil {
            parseState = .argumentsText
            // There may be garbage after the left parenthesis `(`, but we'll
            // still consider subsequent lines for argument text, so we'll
            // indicate acceptance either way at this point.
            _ = parseArgumentsText(from: line)
            return true
        } else {
            parseState = .contentsStart
            return parseContentsStart(from: line)
        }
    }

    /// Continue parsing from the `argumentsText` state.
    @discardableResult
    mutating func parseArgumentsText(from line: TrimmedLine) -> Bool {
        precondition(parseState == .argumentsText)
        var accepted = false
        var line = line
        if let argumentsText = line.lex(until: { $0 == ")" ? .stop : .continue },
                                        allowEscape: true, allowQuote: true) {
            self.argumentsText.append(argumentsText)
            accepted = true
        }
        endLocation = line.location!

        if line.text.starts(with: ")") {
            parseState = .argumentsEnd
            accepted = parseArgumentsEnd(from: line)
        }

        return accepted
    }

    /// Continue parsing from the `argumentsEnd` state.
    @discardableResult
    mutating func parseArgumentsEnd(from line: TrimmedLine) -> Bool {
        precondition(parseState == .argumentsEnd)
        var line = line
        line.lexWhitespace()
        if line.lex(")") != nil {
            parseState = .contentsStart
            endLocation = line.location!
            parseContentsStart(from: line)
            return true
        } else {
            return false
        }
    }

    /// Continue parsing from the `contentsStart` state.
    @discardableResult
    mutating func parseContentsStart(from line: TrimmedLine) -> Bool {
        precondition(parseState == .contentsStart)
        var line = line
        line.lexWhitespace()
        if line.lex("{") != nil {
            parseState = .contents
            endLocation = line.location!
            parseContentsEnd(from: line)
        } else {
            return false
        }
        return true
    }

    /// Continue parsing from the `contentsEnd` state.
    @discardableResult
    mutating func parseContentsEnd(from line: TrimmedLine) -> Bool {
        precondition(isAwaitingChildContent)
        var line = line
        line.lexWhitespace()
        if line.lex("}") != nil {
            parseState = .done
            endLocation = line.location!
        } else {
            // If there is still some content on this line
            // Consider them to be lineRun
            // "@xx { yy": "yy" will be ignored
            // "@xx { yy }": "yy" will be parsed
            // "@xx { yy } zz }" "yy } zz" will be parsed

            var reversedRemainingContent = TrimmedLine(Substring(line.text.reversed()), source: line.source, lineNumber: line.lineNumber)
            reversedRemainingContent.lexWhitespace()
            if !line.text.isEmpty,
               reversedRemainingContent.lex("}") != nil {
                let trailingWhiteSpaceCount = reversedRemainingContent.lexWhitespace()?.text.count ?? 0
                let textCount = line.text.count - trailingWhiteSpaceCount - 1
                let leadingSpacingCount = line.untrimmedText.count - textCount - trailingWhiteSpaceCount - 1
                innerIndentationColumnCount = leadingSpacingCount // Should we add a new property for this kind of usage?
                
                let newLine = String(repeating: " ", count: leadingSpacingCount) + line.untrimmedText.dropFirst(leadingSpacingCount).dropLast(trailingWhiteSpaceCount + 1)
                pendingLine = TrimmedLine(newLine.dropFirst(0), source: line.source, lineNumber: line.lineNumber)
                parseState = .done
                endLocation = SourceLocation(line: line.lineNumber ?? 0, column: line.untrimmedText.count + 1, source: line.source)
            }
            return false
        }
        return true
    }

    /// Accept a line into this block directive container, returning `true`
    /// if the container should be closed.
    ///
    /// - Returns: `true` if this block directive container accepted the line.
    mutating func accept(_ line: TrimmedLine) -> Bool {
        switch parseState {
        case .argumentsStart:
            return parseArgumentsStart(from: line)
        case .argumentsText:
            return parseArgumentsText(from: line)
        case .argumentsEnd:
            return parseArgumentsEnd(from: line)
        case .contentsStart:
            return parseContentsStart(from: line)
        case .contents, .contentsEnd:
            return parseContentsEnd(from: line)
        case .done:
            fatalError("A closed block directive container cannot accept further lines of content.")
        }
    }
}

struct PendingDoxygenCommand {
    enum CommandKind {
        case discussion
        case note
        case abstract
        case param(name: Substring)
        case returns

        var debugDescription: String {
            switch self {
            case .discussion:
                return "'discussion'"
            case .note:
                return "'note'"
            case .abstract:
                return "'abstract'"
            case .param(name: let name):
                return "'param' Argument: '\(name)'"
            case .returns:
                return "'returns'"
            }
        }
    }

    var atLocation: SourceLocation

    var atSignIndentation: Int

    var nameLocation: SourceLocation

    var innerIndentation: Int? = nil

    var kind: CommandKind

    var endLocation: SourceLocation

    var indentationAdjustment: Int {
        innerIndentation ?? atSignIndentation
    }

    mutating func addLine(_ line: TrimmedLine) {
        endLocation = SourceLocation(line: line.lineNumber ?? 0, column: line.untrimmedText.count + 1, source: line.source)

        if innerIndentation == nil, line.location?.line != atLocation.line, !line.isEmptyOrAllWhitespace {
            innerIndentation = line.indentationColumnCount
        }
    }
}

struct TrimmedLine {
    /// A successful result of scanning for a prefix on a ``TrimmedLine``.
    struct Lex: Equatable {
        /// A signal whether to continue searching for characters.
        enum Continuation {
            /// Stop searching.
            case stop
            /// Continue searching.
            case `continue`
        }
        /// The resulting text from scanning a line.
        let text: Substring

        /// The range of the text if known.
        let range: SourceRange?
    }

    /// The original untrimmed text of the line.
    let untrimmedText: Substring

    /// The current index a parser is looking at on a line.
    var parseIndex: Substring.Index

    /// The line number of this line in the source if known, starting with `0`.
    let lineNumber: Int?

    /// The source file or resource from which the line came,
    /// or `nil` if no such file or resource can be identified.
    let source: URL?

    /// `true` if this line is empty or consists of all space `" "` or tab
    /// `"\t"` characters.
    var isEmptyOrAllWhitespace: Bool {
        return text.isEmpty || text.allSatisfy {
            $0 == " " || $0 == "\t"
        }
    }

    /// - Parameters:
    ///   - untrimmedText: The original untrimmed text of the line.
    ///   - source: The source file or resource from which the line came, or `nil` if no such file or resource can be identified.
    ///   - lineNumber: The line number of this line in the source if known, starting with `0`.
    ///   - parseIndex: The current index a parser is looking at on a line, or `nil` if a parser is looking at the start of the untrimmed text.
    init(_ untrimmedText: Substring, source: URL?, lineNumber: Int?, parseIndex: Substring.Index? = nil) {
        self.untrimmedText = untrimmedText
        self.source = source
        self.parseIndex = parseIndex ?? untrimmedText.startIndex
        self.lineNumber = lineNumber
    }

    /// Return the UTF-8 source location of the parse index if the line
    /// number is known.
    var location: SourceLocation? {
        guard let lineNumber = lineNumber else {
            return nil
        }
        let alreadyParsedPrefix = untrimmedText[..<parseIndex]
        return .init(line: lineNumber, column: alreadyParsedPrefix.utf8.count + 1, source: source)
    }

    /// The line's text trimmed of initial indentation.
    var text: Substring {
        return untrimmedText[parseIndex..<untrimmedText.endIndex]
    }

    /// The number of columns of indentation: a space character
    /// is worth one column, whereas a tab character is worth 4.
    var indentationColumnCount: Int {
        return untrimmedText.prefix {
            return $0 == " " || $0 == "\t"
        }
        .reduce(0) { (count, character) -> Int in
            switch character {
            case " ":
                return count + 1
            case "\t":
                // Align up to units of 4.
                // We're using 4 instead of 8 here because cmark has traditionally
                // considered a tab to be equivalent to 4 spaces.
                return (count + 4) & ~0b11
            default:
                fatalError("Non-whitespace character found while calculating equivalent indentation column count")
            }
        }
    }

    var isProbablyCodeFence: Bool {
        var line = self
        line.lexWhitespace()
        return line.text.starts(with: "```") || line.text.starts(with: "~~~")
    }

    /// Take a prefix from the start of the line.
    ///
    /// - parameter `maxLength`: The maximum number of characters to take from the start of the line.
    /// - returns: A ``Lex`` if there were any characters to take, otherwise `nil`.
    mutating func take(_ maxLength: Int, allowEmpty: Bool = false) -> Lex? {
        guard allowEmpty || maxLength > 0 else {
            return nil
        }
        let startIndex = parseIndex
        let startLocation = location
        let consumedText = text.prefix(maxLength)
        guard allowEmpty || !consumedText.isEmpty else {
            return nil
        }
        parseIndex = untrimmedText.index(parseIndex, offsetBy: consumedText.count, limitedBy: untrimmedText.endIndex) ?? untrimmedText.endIndex
        let endIndex = parseIndex
        let endLocation = location
        let text = untrimmedText[startIndex..<endIndex]
        let range: SourceRange?
        if let start = startLocation,
           let end = endLocation {
            range = start..<end
        } else {
            range = nil
        }
        return Lex(text: text, range: range)
    }

    mutating func lex(untilCharacter stopCharacter: Character) -> Lex? {
        return lex { (c) -> Lex.Continuation in
            switch c {
            case stopCharacter:
                return .stop
            default:
                return .continue
            }
        }
    }

    mutating func lex(until stop: (Character) -> Lex.Continuation,
                      allowEscape: Bool = false,
                      allowQuote: Bool = false,
                      allowEmpty: Bool = false) -> Lex? {
        var takeCount = 0
        var prefix = text.makeIterator()
        var isEscaped = false
        var isQuoted = false

        while let c = prefix.next() {
            if isEscaped {
                isEscaped = false
            }
            else if allowEscape,
               c == "\\" {
                isEscaped = true
            }
            else if isQuoted {
                isQuoted = (c != "\"")
            }
            else if allowQuote,
               c == "\"" {
                isQuoted = true
            }
            else if case .stop = stop(c) {
                break
            }
            takeCount += 1
        }

        guard allowEmpty || takeCount > 0 else {
            return nil
        }

        return take(takeCount, allowEmpty: allowEmpty)
    }

    /// Attempt to lex a character from the current parse point.
    ///
    /// - parameter character: the character to expect.
    /// - parameter allowEscape: if `true`, the function will not match the `character`
    ///   if a backslash `\` character precedes it.
    mutating func lex(_ character: Character,
                      allowEscape: Bool = false) -> Lex? {
        var count = 0
        return lex(until: {
            switch ($0, count) {
            case (character, 0):
                count += 1
                return .continue
            default:
                return .stop
            }
        }, allowEscape: allowEscape)
    }

    @discardableResult
    mutating func lexWhitespace(maxLength: Int? = nil) -> Lex? {
        if var maxLength = maxLength {
            let result =  lex {
                guard maxLength > 0,
                      $0 == " " || $0 == "\t" else {
                    return .stop
                }
                maxLength -= 1
                return .continue
            }
            return result
        } else {
            return lex {
                switch $0 {
                case " ", "\t":
                    return .continue
                default:
                    return .stop
                }
            }
        }
    }
}

/// A hierarchy of containers for the first phase of parsing Markdown that includes block directives.
private enum ParseContainer: CustomStringConvertible {
    /// The root document container, which can contain block directives or runs of lines.
    case root([ParseContainer])

    /// A run of lines of regular Markdown.
    case lineRun([TrimmedLine], isInCodeFence: Bool)

    /// A block directive container, which can contain other block directives or runs of lines.
    case blockDirective(PendingBlockDirective, [ParseContainer])

    /// A Doxygen command, which can contain arbitrary markup (but not block directives).
    case doxygenCommand(PendingDoxygenCommand, [TrimmedLine])

    init<TrimmedLines: Sequence>(parsingHierarchyFrom trimmedLines: TrimmedLines, options: ParseOptions) where TrimmedLines.Element == TrimmedLine {
        self = ParseContainerStack(parsingHierarchyFrom: trimmedLines, options: options).top
    }

    var children: [ParseContainer] {
        switch self {
        case .root(let children):
            return children
        case .blockDirective(_, let children):
            return children
        case .lineRun:
            return []
        case .doxygenCommand:
            return []
        }
    }

    var isInCodeFence: Bool {
        guard case let .lineRun(_, inCodeFence) = self,
              inCodeFence else {
            return false
        }
        return true
    }

    private struct Printer {
        var indent = 0
        var pendingNewlines = 0
        var result = ""

        mutating func addressPendingNewlines() {
            for _ in 0..<pendingNewlines {
                result += "\n"
                result += String(repeating: " ", count: indent)
            }
            pendingNewlines = 0
        }

        mutating func queueNewline() {
            pendingNewlines += 1
        }

        mutating private func print<S: StringProtocol>(_ text: S) {
            let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            for i in lines.indices {
                if i != lines.startIndex {
                    queueNewline()
                }
                addressPendingNewlines()
                result += lines[i]
            }
        }

        mutating private func print<Children: Sequence>(children: Children) where Children.Element == ParseContainer {
            queueNewline()
            indent += 4
            for child in children {
                print(container: child)
            }
            indent -= 4
        }

        mutating func print(container: ParseContainer) {
            switch container {
            case .root(let children):
                print("* Root Document")
                print(children: children)
            case .lineRun(let lines, _):
                print("* Line Run")
                queueNewline()
                indent += 4
                for line in lines {
                    print(line.text.debugDescription)
                    queueNewline()
                }
                indent -= 4
            case .blockDirective(let pendingBlockDirective, let children):
                print("* Block directive '\(pendingBlockDirective.name)'")
                if !pendingBlockDirective.argumentsText.isEmpty {
                    queueNewline()
                    indent += 2
                    print("Arguments Text:")
                    indent += 2
                    queueNewline()
                    print(pendingBlockDirective.argumentsText.map { $0.text.debugDescription }.joined(separator: "\n"))
                    indent -= 4
                }
                print(children: children)
            case .doxygenCommand(let pendingDoxygenCommand, let lines):
                print("* Doxygen command \(pendingDoxygenCommand.kind.debugDescription)")
                queueNewline()
                indent += 4
                for line in lines {
                    print(line.text.debugDescription)
                    queueNewline()
                }
                indent -= 4
            }
        }
    }

    var description: String {
        var printer = Printer()
        printer.print(container: self)
        return printer.result
    }

    mutating func updateIndentation(under parent: inout ParseContainer?, for line: TrimmedLine) {
        switch self {
        case .root:
            return
        case .lineRun:
            var newParent: ParseContainer? = nil
            parent?.updateIndentation(under: &newParent, for: line)
        case .blockDirective(var pendingBlockDirective, let children):
            pendingBlockDirective.updateIndentation(for: line)
            self = .blockDirective(pendingBlockDirective, children)
        case .doxygenCommand:
            var newParent: ParseContainer? = nil
            parent?.updateIndentation(under: &newParent, for: line)
        }
    }

    /// The number of characters to remove from the front of a line
    /// in this container to prevent the CommonMark parser from interpreting too
    /// much indentation.
    ///
    /// For example:
    ///
    /// ```
    /// @Thing {
    /// ^ @Thing {
    /// | ^ @Thing {
    /// | | ^ This line has indentation adjustment 4,
    /// | | | for the two spaces after the innermost `@Thing`.
    /// | | | This means that this paragraph is indented only 2 spaces,
    /// | | | not to be interpreted as an indented code block.
    /// | | |
    /// 01234
    /// ```
    ///
    /// Finally, if a line run is a child of a directive, the contents
    /// may be indented to make things easier to read, like so:
    ///
    /// @Outer {
    ///   - A
    ///   - List
    ///   - Within
    /// }
    ///
    /// The line run presented to the CommonMark parser should be:
    /// """
    /// - A
    /// - List
    /// - Within
    /// """
    func indentationAdjustment(under parent: ParseContainer?) -> Int {
        switch self {
        case .root:
            return 0
        case .lineRun:
            return parent?.indentationAdjustment(under: nil) ?? 0
        case .blockDirective(let pendingBlockDirective, _):
            return pendingBlockDirective.indentationColumnCount
        case .doxygenCommand(let pendingCommand, _):
            return pendingCommand.indentationAdjustment
        }
    }

    /// Convert this container to the corresponding ``RawMarkup`` node.
    func convertToRawMarkup(ranges: inout RangeTracker,
                            parent: ParseContainer?,
                            options: ParseOptions) -> [RawMarkup] {
        switch self {
        case let .root(children):
            let rawChildren = children.flatMap {
                $0.convertToRawMarkup(ranges: &ranges, parent: self, options: options)
            }
            return [.document(parsedRange: ranges.totalRange, rawChildren)]
        case let .lineRun(lines, _):
            // Get the maximum number of initial indentation characters to remove from the start
            // of each of these `lines` from the first sibling under `parent` (which could be `self`).
            let indentationColumnCount = indentationAdjustment(under: parent)

            // Trim up to that number of whitespace characters off.
            // We need to keep track of what we removed because cmark will report different source locations than what we
            // had in the source. We'll adjust those when we get them back.
            let trimmedIndentationAndLines = lines.map { line -> (line: TrimmedLine,
                                                                  indentation: Int) in
                var trimmedLine = line
                let trimmedWhitespace = trimmedLine.lexWhitespace(maxLength: indentationColumnCount)
                let indentation = (trimmedWhitespace?.text.count ?? 0) + line.untrimmedText.distance(from: line.untrimmedText.startIndex, to: line.parseIndex)
                return (trimmedLine, indentation)
            }

            // Build the logical block of text that cmark will see.
            let logicalText = trimmedIndentationAndLines
                .map { $0.line.text }
                .joined(separator: "\n")

            // Ask cmark to parse it. Now we have a Markdown `Document` consisting
            // of the contents of this line run.
            let parsedSubdocument = MarkupParser.parseString(logicalText, source: lines.first?.source, options: options)

            // Now, we'll adjust the columns of all of the source positions as
            // needed to offset that indentation trimming we did above.
            // Note that the child identifiers under this document will start at
            // 0, so we will need to adjust those as well, because child identifiers
            // start at 0 from the `root`.

            var columnAdjuster = RangeAdjuster(startLine: lines.first?.lineNumber ?? 1,
                                               ranges: ranges,
                                               trimmedIndentationPerLine: trimmedIndentationAndLines.map { $0.indentation })
            for child in parsedSubdocument.children {
                columnAdjuster.visit(child)
            }

            // Write back the adjusted ranges.
            ranges = columnAdjuster.ranges

            return parsedSubdocument.children.map { $0.raw.markup }
        case let .blockDirective(pendingBlockDirective, children):
            let range = pendingBlockDirective.atLocation..<pendingBlockDirective.endLocation
            ranges.add(range)
            let children = children.flatMap {
                $0.convertToRawMarkup(ranges: &ranges, parent: self, options: options)
            }
            return [
                .blockDirective(
                    name: String(pendingBlockDirective.name),
                    nameLocation: pendingBlockDirective.atLocation,
                    argumentText: DirectiveArgumentText(segments: pendingBlockDirective.argumentsText.map {
                        let base = $0.text.base
                        let lineStartIndex: String.Index
                        if let argumentRange = $0.range {
                            // If the argument has a known source range, offset the column (number of UTF8 bytes) to find the start of the line.
                            lineStartIndex = base.utf8.index($0.text.startIndex, offsetBy: 1 - argumentRange.lowerBound.column)
                        } else if let newLineIndex = base[..<$0.text.startIndex].lastIndex(where: \.isNewline) {
                            // Iterate backwards from the argument start index to find the the start of the line.
                            lineStartIndex = base.utf8.index(after: newLineIndex)
                        } else {
                            lineStartIndex = base.startIndex
                        }
                        let parseIndex = base.utf8.index($0.text.startIndex, offsetBy: -base.utf8.distance(from: base.startIndex, to: lineStartIndex))
                        let untrimmedLine = String(base[lineStartIndex ..< $0.text.endIndex])
                        return DirectiveArgumentText.LineSegment(untrimmedText: untrimmedLine, parseIndex: parseIndex, range: $0.range)
                    }),
                    parsedRange: pendingBlockDirective.atLocation ..< pendingBlockDirective.endLocation,
                    children
                ),
            ]
        case let .doxygenCommand(pendingDoxygenCommand, lines):
            let range = pendingDoxygenCommand.atLocation..<pendingDoxygenCommand.endLocation
            ranges.add(range)
            let children = ParseContainer.lineRun(lines, isInCodeFence: false)
                .convertToRawMarkup(ranges: &ranges, parent: self, options: options)
            switch pendingDoxygenCommand.kind {
            case .discussion:
                return [.doxygenDiscussion(parsedRange: range, children)]
            case .note:
                return [.doxygenNote(parsedRange: range, children)]
            case .abstract:
                return [.doxygenAbstract(parsedRange: range, children)]
            case .param(let name):
                return [.doxygenParam(name: String(name), parsedRange: range, children)]
            case .returns:
                return [.doxygenReturns(parsedRange: range, children)]
            }
        }
    }
}

/// A stack of *open parse containers* into which incoming lines will be added.
///
/// As parse containers on top of the stack are *closed*, they are popped from the
/// stack and added as a child of the next topmost container.
struct ParseContainerStack {
    /// The stack of containers to be incrementally folded into a hierarchy.
    private var stack: [ParseContainer]

    private let options: ParseOptions

    init<TrimmedLines: Sequence>(parsingHierarchyFrom trimmedLines: TrimmedLines, options: ParseOptions) where TrimmedLines.Element == TrimmedLine {
        self.stack = [.root([])]
        self.options = options
        for line in trimmedLines {
            accept(line)
        }
        closeAll()
    }

    /// `true` if the next line would occur inside a block directive.
    private var isInBlockDirective: Bool {
        return stack.first {
            guard case .blockDirective(let pendingBlockDirective, _) = $0,
                  case .contents = pendingBlockDirective.parseState else {
                return false
            }
            return true
        } != nil
    }

    private var canParseDoxygenCommand: Bool {
        guard options.contains(.parseMinimalDoxygen) else { return false }

        guard !isInBlockDirective else { return false }

        if case .lineRun(_, isInCodeFence: let codeFence) = top {
            return !codeFence
        } else {
            return true
        }
    }

    private func isCodeFenceOrIndentedCodeBlock(on line: TrimmedLine) -> Bool {
        // Check if this line is indented 4 or more spaces relative to the current
        // indentation adjustment.
        let indentationAdjustment = top.indentationAdjustment(under: stack.dropLast().last)
        let relativeIndentation = line.indentationColumnCount - indentationAdjustment

        guard relativeIndentation < 4 else {
            return true
        }

        return line.isProbablyCodeFence || top.isInCodeFence
    }

    /// Try to parse a block directive opening from a ``LineSegment``, returning `nil` if
    /// the segment does not open a block directive.
    ///
    /// - Parameter line: The trimmed line to check for a prefix opening a new block directive.
    private func parseBlockDirectiveOpening(on line: TrimmedLine) -> PendingBlockDirective? {
        guard !isCodeFenceOrIndentedCodeBlock(on: line) else {
            return nil
        }
        var remainder = line
        remainder.lexWhitespace()
        guard let at = remainder.lex("@") else {
            return nil
        }

        guard let name = remainder.lex(until: {
            switch $0 {
            case "(", ")", ",", ":", "{", " ", "\t":
                return .stop
            default:
                return .continue
            }
        }, allowEscape: false) else {
            return nil
        }

        var pendingBlockDirective = PendingBlockDirective(atIndentationColumnCount: line.indentationColumnCount,
                                                          atLocation: at.range!.lowerBound,
                                                          nameLocation: name.range!.lowerBound,
                                                          name: name.text,
                                                          endLocation: name.range!.upperBound)

        // There may be garbage after a block directive opening but we were
        // still able to open a new block directive, so we'll consider the
        // rest of the line to be accepted regardless of what comes after.
        _ = pendingBlockDirective.accept(remainder)

        return pendingBlockDirective
    }

    private func parseDoxygenCommandOpening(on line: TrimmedLine) -> (pendingCommand: PendingDoxygenCommand, remainder: TrimmedLine)? {
        guard canParseDoxygenCommand else { return nil }
        guard !isCodeFenceOrIndentedCodeBlock(on: line) else { return nil }

        var remainder = line
        let indent = remainder.lexWhitespace()
        guard let at = remainder.lex(until: { ch in
            switch ch {
            case "@", "\\":
                return .continue
            default:
                return .stop
            }
        }) else { return nil }
        guard let name = remainder.lex(until: { ch in
            if ch.isWhitespace {
                return .stop
            } else {
                return .continue
            }
        }) else { return nil }
        remainder.lexWhitespace()

        let kind: PendingDoxygenCommand.CommandKind
        switch name.text.lowercased() {
        case "discussion":
            kind = .discussion
        case "note":
            kind = .note
        case "brief", "abstract":
            kind = .abstract
        case "param":
            guard let paramName = remainder.lex(until: { ch in
                if ch.isWhitespace {
                    return .stop
                } else {
                    return .continue
                }
            }) else { return nil }
            remainder.lexWhitespace()
            kind = .param(name: paramName.text)
        case "return", "returns", "result":
            kind = .returns
        default:
            return nil
        }

        var pendingCommand = PendingDoxygenCommand(
            atLocation: at.range!.lowerBound,
            atSignIndentation: indent?.text.count ?? 0,
            nameLocation: name.range!.lowerBound,
            kind: kind,
            endLocation: name.range!.upperBound)
        pendingCommand.addLine(remainder)
        return (pendingCommand, remainder)
    }

    /// Accept a trimmed line, opening new block directives as indicated by the source,
    /// closing a block directive if applicable, or adding the line to a run of lines to be parsed
    /// as Markdown later.
    private mutating func accept(_ line: TrimmedLine) {
        if line.isEmptyOrAllWhitespace {
            switch top {
            case let .blockDirective(pendingBlockDirective, _):
                switch pendingBlockDirective.parseState {
                case .argumentsStart,
                     .contentsStart,
                     .done:
                    closeTop()

                default:
                    break
                }
            case .doxygenCommand:
                closeTop()
            default:
                break
            }
        }

        // If we can parse a Doxygen command from this line, start one and skip everything else.
        if let result = parseDoxygenCommandOpening(on: line) {
            switch top {
            case .root:
                break
            default:
                closeTop()
            }
            push(.doxygenCommand(result.pendingCommand, [result.remainder]))
            return
        }

        // If we're inside a block directive, check to see whether we need to update its
        // indentation calculation to account for its content.
        updateIndentation(for: line)

        // Check to see if this line closes a block directive with a right
        // curly brace. This may implicitly close several directives, such as in
        // the following scenario:
        //
        // @Outer {
        //   @WillBeClosedImplicitly
        //   @WillBeClosedImplicitly
        // }
        //
        // The last right curly brace } will close the second `@WillBeClosedImplicitly` implicitly,
        // as the right curly brace } is meant to close `@Outer`.
        if !isCodeFenceOrIndentedCodeBlock(on: line) {
            var line = line
            line.lexWhitespace()
            if line.lex("}") != nil {
                // Try to find a topmost open block directive on the stack
                // that is in the parse state `.contents` or `.contentsEnd`.
                // This right curly brace is meant for it.
                let foundIndex = stack.reversed().firstIndex {
                    guard case .blockDirective(let pendingBlockDirective, _) = $0,
                          pendingBlockDirective.isAwaitingChildContent else {
                        return false
                    }
                    return true
                }

                if let foundIndex = foundIndex {
                    let startIndex = stack.reversed().startIndex
                    let closeCount = stack.reversed().distance(from: startIndex, to: foundIndex)
                    for _ in 0..<closeCount {
                        closeTop()
                    }
                }
            }
        }

        if let newBlockDirective = parseBlockDirectiveOpening(on: line) {
            // The source indicates opening a new block directive.
            switch top {
            case .root:
                push(.blockDirective(newBlockDirective, []))
            case .lineRun, .doxygenCommand:
                closeTop()
                push(.blockDirective(newBlockDirective, []))
            case .blockDirective(let previousBlockDirective, _):
                switch previousBlockDirective.parseState {
                case .contents:
                    // This new block directive will be a child of the one just parsed.
                    push(.blockDirective(newBlockDirective, []))
                case .argumentsText:
                    // Unclosed arguments list?
                    fallthrough
                default:
                    // Otherwise, this will be considered a sibling at the current level.
                    closeTop()
                    push(.blockDirective(newBlockDirective, []))
                }
            }
            if let pendingLine = newBlockDirective.pendingLine {
                push(.lineRun([pendingLine], isInCodeFence: false))
            }
            if case .done = newBlockDirective.parseState {
                closeTop()
            }
        } else {
            switch top {
            case .root:
                push(.lineRun([line], isInCodeFence: line.isProbablyCodeFence))
            case .lineRun(var lines, let isInCodeFence):
                pop()
                lines.append(line)
                push(.lineRun(lines, isInCodeFence: isInCodeFence != line.isProbablyCodeFence))
            case .doxygenCommand(var pendingDoxygenCommand, var lines):
                pop()
                lines.append(line)
                pendingDoxygenCommand.addLine(line)
                push(.doxygenCommand(pendingDoxygenCommand, lines))
            case .blockDirective(var pendingBlockDirective, let children):
                // A pending block directive can accept this line if it is in the middle of
                // parsing arguments text (to allow indentation to align arguments) or
                // if the line isn't taking part in a code block.
                let canAcceptLine =
                    pendingBlockDirective.parseState != .done &&
                    (pendingBlockDirective.parseState == .argumentsText ||
                     !isCodeFenceOrIndentedCodeBlock(on: line))
                if canAcceptLine && pendingBlockDirective.accept(line) {
                    pop()
                    push(.blockDirective(pendingBlockDirective, children))
                    if case .done = pendingBlockDirective.parseState {
                        closeTop()
                    }
                } else {
                    if !pendingBlockDirective.isAwaitingChildContent {
                        closeTop()
                    }
                    push(.lineRun([line], isInCodeFence: line.isProbablyCodeFence))
                }
            }
        }
    }

    private mutating func updateIndentation(for line: TrimmedLine) {
        var parent = stack.dropLast().last
        top.updateIndentation(under: &parent, for: line)
        if let parent = parent {
            stack[stack.count - 2] = parent
        }
    }

    /// The top container on the stack, which is always present.
    fileprivate var top: ParseContainer {
        get {
            return stack.last!
        }
        set(newTop) {
            precondition(stack.count > 0)
            stack[stack.count - 1] = newTop
        }
    }

    /// Close all open containers, returning the final, root document container.
    private mutating func closeAll() {
        while stack.count > 1 {
            closeTop()
        }
    }

    /// Remove the topmost container and add it as a child to the one underneath.
    ///
    /// - Precondition: There must be at least two elements on the stack, one to be removed as the child, and one to accept the child as a parent.
    /// - Precondition: The container underneath the top container must not be a line run as they cannot have children.
    private mutating func closeTop() {
        precondition(stack.count > 1)
        let child = pop()

        if case .blockDirective(let pendingBlockDirective, _) = child,
           pendingBlockDirective.parseState == .contents ||
            pendingBlockDirective.parseState == .contentsEnd {
            // Unclosed block directive?
        }

        switch pop() {
        case .root(var children):
            children.append(child)
            push(.root(children))
        case .blockDirective(let pendingBlockDirective, var children):
            children.append(child)
            push(.blockDirective(pendingBlockDirective, children))
        case .lineRun:
            fatalError("Line runs cannot have children")
        case .doxygenCommand:
            fatalError("Doxygen commands cannot have children")
        }
    }

    /// Open a new container and place it at the top of the stack.
    private mutating func push(_ container: ParseContainer) {
        if case .root = container, !stack.isEmpty {
            fatalError("Cannot push additional document containers onto the parse container stack")
        }
        stack.append(container)
    }

    @discardableResult
    private mutating func pop() -> ParseContainer {
        return stack.popLast()!
    }
}

extension Document {
    /// Convert a ``ParseContainer` to a ``Document``.
    ///
    /// - Precondition: The `rootContainer` must be the `.root` case.
    fileprivate init(converting rootContainer: ParseContainer, from source: URL?,
                     options: ParseOptions) {
        guard case .root = rootContainer else {
            fatalError("Tried to convert a non-root container to a `Document`")
        }

        var rangeTracker = RangeTracker(totalRange: SourceLocation(line: 1, column: 1, source: source)..<SourceLocation(line: 1, column: 1, source: source))
        let rootId = MarkupIdentifier.newRoot()
        let result = rootContainer.convertToRawMarkup(ranges: &rangeTracker, parent: nil, options: options)

        guard let rawDocument = result.first,
              case .document = rawDocument.header.data,
              result.count == 1 else {
            fatalError("Conversion from ParseContainer.document to RawMarkup.document failed")
        }

        let metadata = MarkupMetadata(id: rootId, indexInParent: 0)
        let absoluteRaw = AbsoluteRawMarkup(markup: rawDocument, metadata: metadata)
        let data = _MarkupData(absoluteRaw)
        self.init(data)
    }
}

struct BlockDirectiveParser {
    static func parse(_ input: URL, options: ParseOptions = []) throws -> Document {
        let string = try String(contentsOf: input, encoding: .utf8)
        return parse(string, source: input, options: options)
    }

    /// Parse the input.
    static func parse(_ input: String, source: URL?,
                      options: ParseOptions = []) -> Document {
        // Phase 0: Split the input into lines lazily, keeping track of
        // line numbers, consecutive blank lines, and start positions on each line where indentation ends.
        // These trim points may be used to adjust the indentation seen by the CommonMark parser when
        // the need to parse regular markdown lines arises.
        let trimmedLines = LazySplitLines(input[...], source: source)

        // Phase 1: Categorize the lines into a hierarchy of block containers by parsing the prefix
        // of the line, opening and closing block directives appropriately, and folding elements
        // into a root document.
        let rootContainer = ParseContainer(parsingHierarchyFrom: trimmedLines, options: options)

        // Phase 2: Convert the hierarchy of block containers into a real ``Document``.
        // This is where the CommonMark parser is called upon to parse runs of lines of content,
        // adjusting source locations back to the original source.
        return Document(converting: rootContainer, from: source, options: options)
    }
}
