/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation
import Markdown

/// A convenience enum to allow the command line to have separate options
/// for counting behavior and start numeral.
enum OrderedListCountingBehavior: String, ExpressibleByArgument, CaseIterable {
    /// Use the same numeral for all ordered list items, inferring order.
    case allSame = "all-same"

    /// Literally increment the numeral for each list item in a list.
    case incrementing
}

extension ExpressibleByArgument where Self: RawRepresentable, Self.RawValue == String {
    public init?(argument: String) {
        self.init(rawValue: argument)
    }
}

/// A convenience enum to allow the command line to validate the maximum line length.
struct MaximumLineLength: ExpressibleByArgument {
    var length: Int
    init?(length: Int) {
        guard length > 0 else {
            return nil
        }
        self.length = length
    }

    init?(argument: String) {
        guard let length = Int(argument) else {
            return nil
        }
        self.init(length: length)
    }
}

extension MarkupFormatter.Options.UnorderedListMarker: ExpressibleByArgument {}
extension MarkupFormatter.Options.UseCodeFence: ExpressibleByArgument {}
extension MarkupFormatter.Options.ThematicBreakCharacter: ExpressibleByArgument {}
extension MarkupFormatter.Options.EmphasisMarker: ExpressibleByArgument {}
extension MarkupFormatter.Options.PreferredHeadingStyle: ExpressibleByArgument {}
extension MarkupFormatter.Options.PreferredLineLimit.SplittingElement:  ExpressibleByArgument {}

extension MarkdownCommand {
    /**
     Takes formatting options and markdown on standard input, applying those options while printing to standard output.
     */
    struct Format: ParsableCommand {
        enum Error: LocalizedError {
            case formattedOutputHasDifferentStructures
            case diffingFailed
            var errorDescription: String? {
                switch self {
                case .formattedOutputHasDifferentStructures:
                    return "Formatted output did not have same structure as the output."
                case .diffingFailed:
                    return "Failed to diff original and formatted tree representations"
                }
            }
        }
        static let configuration = CommandConfiguration(commandName: "format", abstract: "Format markdown on standard input to standard output")

        @Option(help: "Ordered list start numeral")
        var orderedListStartNumeral: UInt = 1

        @Option(help: "Ordered list counting; choices: \(OrderedListCountingBehavior.allCases.map { $0.rawValue }.joined(separator: ", "))")
        var orderedListCounting: OrderedListCountingBehavior = .allSame

        @Option(help: "Unordered list marker; choices: \(MarkupFormatter.Options.UnorderedListMarker.allCases.map { $0.rawValue }.joined(separator: ", "))")
        var unorderedListMarker: String = "-"

        @Option(help: "Use fenced code blocks; choices: \(MarkupFormatter.Options.UseCodeFence.allCases.map { $0.rawValue }.joined(separator: ", "))")
        var useCodeFence: MarkupFormatter.Options.UseCodeFence = .always

        @Option(help: "Default code block language to use for fenced code blocks")
        var defaultCodeBlockLanguage: String?

        @Option(help: "The character to use for thematic breaks; choices: \(MarkupFormatter.Options.ThematicBreakCharacter.allCases.map { $0.rawValue }.joined(separator: ", "))")
        var thematicBreakCharacter: MarkupFormatter.Options.ThematicBreakCharacter = .dash

        @Option(help: "The length of thematic breaks")
        var thematicBreakLength: UInt = 5

        @Option(help: "Emphasis marker; choices: \(MarkupFormatter.Options.EmphasisMarker.allCases.map { $0.rawValue }.joined(separator: ", "))")
        var emphasisMarker: String = "*"

        @Flag(inversion: .prefixedNo, exclusivity: .chooseLast, help: "Condense links whose text matches their destination to 'autolinks' e.g. <https://swift.org>")
        var condenseAutolinks: Bool = true

        @Option(help: "Preferred heading style; choices: \(MarkupFormatter.Options.PreferredHeadingStyle.allCases.map { $0.rawValue }.joined(separator: ", "))")
        var preferredHeadingStyle: MarkupFormatter.Options.PreferredHeadingStyle = .atx

        @Option(help: "Preferred maximum line length, enforced with hard or soft breaks to split text elements where possible (see --line-splitting-element)")
        var preferredMaximumLineLength: MaximumLineLength?

        @Option(help: "The kind of element to use to split text elements while enforcing --preferred-maximum-line-length; choices: \(MarkupFormatter.Options.PreferredLineLimit.SplittingElement.allCases.map { $0.rawValue }.joined(separator: ", "))")
        var lineSplittingElement: MarkupFormatter.Options.PreferredLineLimit.SplittingElement = .softBreak

        @Option(help: "Prepend this prefix to every line")
        var customLinePrefix: String = ""

        @Flag(inversion: .prefixedNo, exclusivity: .chooseLast, help: "Check that the formatted output is structurally equivalent (has the same AST structure) to the input")
        var checkStructuralEquivalence: Bool = false

        @Flag<Bool>(inversion: .prefixedNo, exclusivity: .chooseLast, help: "Parse block directives")
        var parseBlockDirectives: Bool = false

        @Flag<Bool>(inversion: .prefixedNo, exclusivity: .chooseLast, help: "Interpret inline code spans with two backticks as a symbol link element")
        var parseSymbolLinks: Bool = false

        @Argument(help: "Input file (default: standard input)")
        var inputFilePath: String?

        /// Search for the an executable with a given base name.
        func findExecutable(named name: String) throws -> String? {
            let which = Process()
            which.arguments = [name]
            let standardOutput = Pipe()
            which.standardOutput = standardOutput
            if #available(macOS 10.13, *) {
                which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
                try which.run()
            } else {
                which.launchPath = "/usr/bin/which"
                which.launch()
            }
            which.waitUntilExit()

            guard which.terminationStatus == 0,
                let output = String(data: standardOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
                    return nil
            }

            return output.trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
        }

        func checkStructuralEquivalence(between original: Document,
                                        and formatted: Document,
                                        source: String) throws {
            struct FileHandlerOutputStream: TextOutputStream {
                private let fileHandle: FileHandle
                let encoding: String.Encoding

                init(_ fileHandle: FileHandle, encoding: String.Encoding = .utf8) {
                    self.fileHandle = fileHandle
                    self.encoding = encoding
                }

                mutating func write(_ string: String) {
                    if let data = string.data(using: encoding) {
                        fileHandle.write(data)
                    }
                }
            }

            var standardError = FileHandlerOutputStream(FileHandle.standardError, encoding: .utf8)

            guard preferredMaximumLineLength == nil else {
                print("Skipping structural equivalence check because --preferred-maximum-line-length was used, which can intentionally change document structure by inserting soft or hard line breaks.", to: &standardError)
                return
            }

            if !original.hasSameStructure(as: formatted) {
                print("Error: Formatted markup tree had different structure from the original!", to: &standardError)
                print("Please file a bug with the following information:", to: &standardError)
                print("Original source:", to: &standardError)
                print("```markdown", to: &standardError)
                print(source, to: &standardError)
                print("```", to: &standardError)
                print("Original structure:", to: &standardError)
                print(original.debugDescription(), to: &standardError)
                print("----------------", to: &standardError)
                print("Structure after formatting:", to: &standardError)
                print(formatted.debugDescription(), to: &standardError)
                throw Error.formattedOutputHasDifferentStructures
            }
        }

        func run() throws {
            var parseOptions = ParseOptions()
            if parseBlockDirectives {
                parseOptions.insert(.parseBlockDirectives)
            }
            if parseSymbolLinks {
                parseOptions.insert(.parseSymbolLinks)
            }
            let source: String
            let document: Document
            if let inputFilePath = inputFilePath {
                (source, document) = try MarkdownCommand.parseFile(at: inputFilePath, options: parseOptions)
            } else {
                (source, document) = try MarkdownCommand.parseStandardInput(options: parseOptions)
            }

            guard let emphasisMarker = MarkupFormatter.Options.EmphasisMarker(argument: emphasisMarker) else {
                throw ArgumentParser.ValidationError("The value '\(self.emphasisMarker)' is invalid for '--emphasis-marker'")
            }

            guard let unorderedListMarker = MarkupFormatter.Options.UnorderedListMarker(argument: unorderedListMarker) else {
                throw ArgumentParser.ValidationError("The value '\(self.emphasisMarker)' is invalid for '--unordered-list-marker'")
            }

            let orderedListNumerals: MarkupFormatter.Options.OrderedListNumerals
            switch orderedListCounting {
            case .allSame:
                orderedListNumerals = .allSame(orderedListStartNumeral)
            case .incrementing:
                orderedListNumerals = .incrementing(start: orderedListStartNumeral)
            }

            let preferredLineLimit = preferredMaximumLineLength.map {
                MarkupFormatter.Options.PreferredLineLimit(maxLength: $0.length, breakWith: lineSplittingElement)
            }

            let formatOptions = MarkupFormatter.Options(unorderedListMarker: unorderedListMarker,
                                                  orderedListNumerals: orderedListNumerals,
                                                  useCodeFence: useCodeFence,
                                                  defaultCodeBlockLanguage: defaultCodeBlockLanguage,
                                                  thematicBreakCharacter: thematicBreakCharacter,
                                                  thematicBreakLength: thematicBreakLength,
                                                  emphasisMarker: emphasisMarker,
                                                  condenseAutolinks: condenseAutolinks,
                                                  preferredHeadingStyle: preferredHeadingStyle,
                                                  preferredLineLimit: preferredLineLimit,
                                                  customLinePrefix: customLinePrefix)
            let formatted = document.format(options: formatOptions)
            print(formatted)
            if checkStructuralEquivalence {
                try checkStructuralEquivalence(between: document,
                                               and: Document(parsing: formatted, options: parseOptions),
                                               source: source)
            }
        }
    }
}
