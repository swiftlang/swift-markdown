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
    struct PrintHtml: ParsableCommand {
        static var configuration = CommandConfiguration(commandName: "print-html", abstract: "Convert Markdown content into HTML")

        @Argument(
            help: "Input file to print (default: standard input)",
            completion: .file()
        )
        var inputFilePath: String?

        func run() throws {
            let document: Document
            if let inputFilePath = inputFilePath {
                (_, document) = try MarkdownCommand.parseFile(at: inputFilePath, options: [])
            } else {
                (_, document) = try MarkdownCommand.parseStandardInput(options: [])
            }

            var visitor = HtmlFormatter()
            visitor.visit(document)

            print(visitor.result)
        }
    }
}
