/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
import Markdown

final class DocumentTests: XCTestCase {
    func testDocumentFromSequence() {
        let children = [
            Paragraph(Text("First")),
            Paragraph(Text("Second")),
        ]
        let document = Document(children)
        let expectedDump = """
            Document
            ├─ Paragraph
            │  └─ Text "First"
            └─ Paragraph
               └─ Text "Second"
            """
        XCTAssertEqual(expectedDump, document.debugDescription())
    }

    func testParseURL() {
        let readmeURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Block Nodes
            .appendingPathComponent("..") // MarkupTests
            .appendingPathComponent("..") // Tests
            .appendingPathComponent("..") // Project
            .appendingPathComponent("README.md")
        XCTAssertNoThrow(try Document(parsing: readmeURL))
        XCTAssertThrowsError(try Document(parsing: URL(fileURLWithPath: #file)
            .appendingPathComponent("doesntexist")))
    }
 
    func testParseNewlineCharacters() {
        let inputParagraphString = """
        # First\n
        ## Second\r
        ### Third\r\n
        """
        let document = Document(parsing: inputParagraphString, options: [.parseBlockDirectives, .parseSymbolLinks])
        let expectedDump = """
                Document
                ├─ Heading level: 1
                │  └─ Text "First"
                ├─ Heading level: 2
                │  └─ Text "Second"
                └─ Heading level: 3
                   └─ Text "Third"
                """
        XCTAssertEqual(expectedDump, document.debugDescription())
    }
    
    func testParsingBlockDirectiveWithCRLFLineEndings() {
        let input = "@Comment {\r\n    This is a comment\r}\n"
        let options: ParseOptions = [.parseBlockDirectives, .parseSymbolLinks]
        let document = Document(parsing: input, options: options)
        XCTAssertNotNil(document)
    }
    
    func testParsingNestedBlockDirectivesWithMixedCRLFLineEndings() {
        let input = "@Outer {\n    @Inner {\r\n        content\n    }\r\n}\r\n"
        let options: ParseOptions = [.parseBlockDirectives, .parseSymbolLinks]
        let document = Document(parsing: input, options: options)
        XCTAssertNotNil(document)
    }
    
    func testParsingSimpleFileCRLFLineEndings() {
        let input = "4bf5d-496d7\r\n04c8f-c1484\r\n622aa-0210e\r\n1bf50-1f7e2\r\nfdc17-d25e2\r\n4de63-510a3\r\n"
        let options: ParseOptions = [.parseBlockDirectives, .parseSymbolLinks]
        let document = Document(parsing: input, options: options)
        XCTAssertNotNil(document)
        let expectedDump = """
                Document
                └─ Paragraph
                   ├─ Text "4bf5d-496d7"
                   ├─ SoftBreak
                   ├─ Text "04c8f-c1484"
                   ├─ SoftBreak
                   ├─ Text "622aa-0210e"
                   ├─ SoftBreak
                   ├─ Text "1bf50-1f7e2"
                   ├─ SoftBreak
                   ├─ Text "fdc17-d25e2"
                   ├─ SoftBreak
                   └─ Text "4de63-510a3"
                """
        XCTAssertEqual(expectedDump, document.debugDescription())
    }
}
