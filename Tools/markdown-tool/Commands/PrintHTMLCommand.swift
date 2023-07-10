/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Markdown

extension MarkdownCommand {
    /// A command to render HTML for given Markdown content.
    struct PrintHTML: ParsableCommand {
        static var configuration = CommandConfiguration(commandName: "print-html", abstract: "Convert Markdown content into HTML")

        @Argument(
            help: "Input file to print (default: standard input)",
            completion: .file()
        )
        var inputFilePath: String?

        @Flag(
            inversion: .prefixedNo,
            exclusivity: .chooseLast,
            help: "Parse block quotes as asides if they have an aside marker"
        )
        var parseAsides: Bool = false

        @Flag(
            inversion: .prefixedNo,
            exclusivity: .chooseLast,
            help: "Parse inline attributes as JSON, and use the 'class' property as a 'class' attribute"
        )
        var parseInlineAttributeClass: Bool = false

        func run() throws {
            let document: Document
            if let inputFilePath = inputFilePath {
                (_, document) = try MarkdownCommand.parseFile(at: inputFilePath, options: [])
            } else {
                (_, document) = try MarkdownCommand.parseStandardInput(options: [])
            }

            var formatterOptions = HTMLFormatterOptions()
            if parseAsides {
                formatterOptions.insert(.parseAsides)
            }
            if parseInlineAttributeClass {
                formatterOptions.insert(.parseInlineAttributeClass)
            }

            print(HTMLFormatter.format(document, options: formatterOptions))
        }
    }
}
