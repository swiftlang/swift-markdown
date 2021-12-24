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

        @Option(help: "Additional Commonmark extensions to enable")
        var `extension`: [String] = []

        @Flag<Bool>(help: "Don't enable the default Commonmark extensions (\(ConvertOptions.defaultCommonmarkExtensions.joined(separator: ", ")))")
        var noDefaultExtensions: Bool = false

        func run() throws {
            let parseOptions: ParseOptions = parseBlockDirectives ? [.parseBlockDirectives] : []
            var commonmarkExts = noDefaultExtensions ? [] : ConvertOptions.defaultCommonmarkExtensions
            commonmarkExts.append(contentsOf: `extension`)
            let convertOptions = ConvertOptions.init(
                parseOptions: parseOptions,
                commonmarkOptions: ConvertOptions.defaultCommonmarkOptions,
                extensions: commonmarkExts
            )

            let document: Document
            if let inputFilePath = inputFilePath {
                (_, document) = try MarkdownCommand.parseFile(at: inputFilePath, options: convertOptions)
            } else {
                (_, document) = try MarkdownCommand.parseStandardInput(options: convertOptions)
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
