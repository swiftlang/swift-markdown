/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Markdown

extension MarkdownCommand {
    /// A command to dump the parsed input's debug tree representation.
    struct DumpTree: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "dump-tree", abstract: "Dump the parsed standard input as a tree representation for debugging")

        @Argument(help: "Optional input file path of a Markdown file to format; default: standard input")
        var inputFilePath: String?

        @Flag(inversion: .prefixedNo, exclusivity: .chooseLast, help: "Print source locations for each element where applicable")
        var sourceLocations: Bool = false

        @Flag<Bool>(inversion: .prefixedNo, exclusivity: .chooseLast, help: "Print internal unique identifiers for each element")
        var uniqueIdentifiers: Bool = false

        @Flag<Bool>(inversion: .prefixedNo, exclusivity: .chooseLast, help: "Parse block directives")
        var parseBlockDirectives: Bool = false

        func run() throws {
            let parseOptions: ParseOptions = parseBlockDirectives ? [.parseBlockDirectives] : []
            let document: Document
            if let inputFilePath = inputFilePath {
                (_, document) = try MarkdownCommand.parseFile(at: inputFilePath, options: parseOptions)
            } else {
                (_, document) = try MarkdownCommand.parseStandardInput(options: parseOptions)
            }
            var dumpOptions = MarkupDumpOptions()
            if sourceLocations {
                dumpOptions.insert(.printSourceLocations)
            }
            if uniqueIdentifiers {
                dumpOptions.insert(.printUniqueIdentifiers)
            }
            print(document.debugDescription(options: dumpOptions))
        }
    }
}
