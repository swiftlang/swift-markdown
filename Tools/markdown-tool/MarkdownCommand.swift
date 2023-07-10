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

@main
struct MarkdownCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "markdown", shouldDisplay: false, subcommands: [
        DumpTree.self,
        Format.self,
        PrintHTML.self,
    ])

    static func parseFile(at path: String, options: ParseOptions) throws -> (source: String, parsed: Document) {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let inputString = String(decoding: data, as: UTF8.self)
        return (inputString, Document(parsing: inputString, options: options))
    }

    static func parseStandardInput(options: ParseOptions) throws -> (source: String, parsed: Document) {
        let stdinData: Data
        if #available(macOS 10.15.4, *) {
            stdinData = try FileHandle.standardInput.readToEnd() ?? Data()
        } else {
            stdinData = FileHandle.standardInput.readDataToEndOfFile()
        }
        let stdinString = String(decoding: stdinData, as: UTF8.self)
        return (stdinString, Document(parsing: stdinString, options: options))
    }
}
