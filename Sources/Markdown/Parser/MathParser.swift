/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

struct MathParser {
    static func parse(_ document: Document, options: ParseOptions) -> Document {
        guard options.contains(.parseMath) else {
            return document
        }
        var rewriter = MathRewriter()
        guard let rewritten = rewriter.visit(document) as? Document else {
            return document
        }
        return rewritten
    }
}

fileprivate struct MathRewriter: MarkupRewriter {
    mutating func defaultVisit(_ markup: Markup) -> Markup? {
        var newChildren = [Markup]()
        for child in markup.children {
            if let text = child as? Text {
                newChildren.append(contentsOf: splitInlineMath(in: text))
            } else if let rewritten = visit(child) {
                newChildren.append(rewritten)
            }
        }
        return markup.withUncheckedChildren(newChildren)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> Markup? {
        guard let code = blockMathCode(from: paragraph) else {
            return defaultVisit(paragraph)
        }
        return try! BlockMath(.blockMath(parsedRange: paragraph.range, code: code))
    }

    private func blockMathCode(from paragraph: Paragraph) -> String? {
        var rawText = ""
        for child in paragraph.children {
            if let text = child as? Text {
                rawText += text.string
            } else if child is SoftBreak || child is LineBreak {
                rawText += "\n"
            } else {
                return nil
            }
        }

        let lines = rawText.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard !lines.isEmpty else {
            return nil
        }

        let firstLine = lines[lines.startIndex].trimmingCharacters(in: .whitespaces)
        let lastLine = lines[lines.index(before: lines.endIndex)].trimmingCharacters(in: .whitespaces)

        if lines.count >= 2, firstLine == "$$", lastLine == "$$" {
            return lines.dropFirst().dropLast().joined(separator: "\n")
        }

        guard lines.count == 1 else {
            return nil
        }
        guard firstLine.count >= 4,
              firstLine.hasPrefix("$$"),
              firstLine.hasSuffix("$$") else {
            return nil
        }

        return String(firstLine.dropFirst(2).dropLast(2))
    }

    private func splitInlineMath(in text: Text) -> [Markup] {
        let source = text.string
        var result = [Markup]()
        var foundMath = false

        var currentIndex = source.startIndex
        var pendingTextStart = source.startIndex

        while currentIndex < source.endIndex {
            guard canOpenInlineMathDelimiter(in: source, at: currentIndex) else {
                currentIndex = source.index(after: currentIndex)
                continue
            }

            let codeStart = source.index(after: currentIndex)
            var closingIndex = codeStart
            var foundClosingDelimiter = false

            while closingIndex < source.endIndex {
                if canCloseInlineMathDelimiter(in: source, at: closingIndex) {
                    foundClosingDelimiter = true
                    break
                }
                closingIndex = source.index(after: closingIndex)
            }

            guard foundClosingDelimiter else {
                currentIndex = source.index(after: currentIndex)
                continue
            }

            if pendingTextStart < currentIndex {
                result.append(
                    try! Text(
                        .text(
                            parsedRange: slicedRange(in: text, source: source, slice: pendingTextStart..<currentIndex),
                            string: String(source[pendingTextStart..<currentIndex])
                        )
                    )
                )
            }

            let afterClosingDelimiter = source.index(after: closingIndex)
            result.append(
                try! InlineMath(
                    .inlineMath(
                        parsedRange: slicedRange(in: text, source: source, slice: currentIndex..<afterClosingDelimiter),
                        code: String(source[codeStart..<closingIndex])
                    )
                )
            )
            foundMath = true

            pendingTextStart = afterClosingDelimiter
            currentIndex = afterClosingDelimiter
        }

        guard foundMath else {
            return [text]
        }

        if pendingTextStart < source.endIndex {
            result.append(
                try! Text(
                    .text(
                        parsedRange: slicedRange(in: text, source: source, slice: pendingTextStart..<source.endIndex),
                        string: String(source[pendingTextStart..<source.endIndex])
                    )
                )
            )
        }

        return result
    }

    private func canOpenInlineMathDelimiter(in source: String, at index: String.Index) -> Bool {
        guard source[index] == "$",
              !isEscaped(in: source, at: index),
              isSingleDollarDelimiter(in: source, at: index) else {
            return false
        }

        let nextIndex = source.index(after: index)
        guard nextIndex < source.endIndex else {
            return false
        }
        return !source[nextIndex].isWhitespace
    }

    private func canCloseInlineMathDelimiter(in source: String, at index: String.Index) -> Bool {
        guard source[index] == "$",
              !isEscaped(in: source, at: index),
              isSingleDollarDelimiter(in: source, at: index),
              index > source.startIndex else {
            return false
        }

        let previousIndex = source.index(before: index)
        return !source[previousIndex].isWhitespace
    }

    private func isSingleDollarDelimiter(in source: String, at index: String.Index) -> Bool {
        if index > source.startIndex {
            let previousIndex = source.index(before: index)
            if source[previousIndex] == "$" {
                return false
            }
        }

        let nextIndex = source.index(after: index)
        if nextIndex < source.endIndex, source[nextIndex] == "$" {
            return false
        }

        return true
    }

    private func isEscaped(in source: String, at index: String.Index) -> Bool {
        var backslashCount = 0
        var previousIndex = index

        while previousIndex > source.startIndex {
            let candidate = source.index(before: previousIndex)
            guard source[candidate] == "\\" else {
                break
            }
            backslashCount += 1
            previousIndex = candidate
        }

        return backslashCount % 2 == 1
    }

    private func slicedRange(in text: Text, source: String, slice: Range<String.Index>) -> SourceRange? {
        guard let range = text.range,
              range.lowerBound.line == range.upperBound.line else {
            return nil
        }

        let lowerOffset = source.utf8.distance(from: source.startIndex, to: slice.lowerBound)
        let upperOffset = source.utf8.distance(from: source.startIndex, to: slice.upperBound)

        let line = range.lowerBound.line
        let sourceURL = range.lowerBound.source
        let lowerBound = SourceLocation(line: line, column: range.lowerBound.column + lowerOffset, source: sourceURL)
        let upperBound = SourceLocation(line: line, column: range.lowerBound.column + upperOffset, source: sourceURL)
        return lowerBound..<upperBound
    }
}
