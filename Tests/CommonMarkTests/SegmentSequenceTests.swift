/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

@Suite("Segment Sequence Tests")
struct SegmentsTests {

    @Test("literalSegments concatenation equals literal() for inline text and code")
    func inlineTextMatches() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let source = "hello *world* and `code`"
        try MarkdownDocument.withParsedDocument(source) { doc in
        var literals: [String] = []
        var joined: [String] = []
        let root = doc.root
        root.children.forEach { paragraph in
            paragraph.children.forEach { inline in
                if let lit = inline.literal() {
                    literals.append(lit)
                    var bytes: [UInt8] = []
                    inline.literalSegments().forEach { span in
                        let raw = span.span
                        for i in 0..<raw.count {
                            bytes.append(raw[i])
                        }
                    }
                    joined.append(String(decoding: bytes, as: UTF8.self))
                }
                // One level into the emphasis node.
                inline.children.forEach { nested in
                    if let lit = nested.literal() {
                        literals.append(lit)
                        var bytes: [UInt8] = []
                        nested.literalSegments().forEach { span in
                            let raw = span.span
                            for i in 0..<raw.count {
                                bytes.append(raw[i])
                            }
                        }
                        joined.append(String(decoding: bytes, as: UTF8.self))
                    }
                }
            }
        }
        #expect(!literals.isEmpty)
        #expect(joined == literals)
        #expect(literals.contains("world"))
        #expect(literals.contains("code"))
        }
    }

    @Test("literalSegments equals literal() across a multi-line paragraph")
    func multiLineParagraph() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        // A multi-line paragraph exercises the contiguity fast path: its text runs are source ranges; the iterator must still reproduce literal().
        let source = "first line\nsecond line\nthird line"
        try MarkdownDocument.withParsedDocument(source) { doc in
        var pieces: [String] = []
        let root = doc.root
        root.children.forEach { paragraph in
            paragraph.children.forEach { inline in
                if inline.kind == .text {
                    var bytes: [UInt8] = []
                    inline.literalSegments().forEach { span in
                        let raw = span.span
                        for i in 0..<raw.count {
                            bytes.append(raw[i])
                        }
                    }
                    let joined = String(decoding: bytes, as: UTF8.self)
                    pieces.append(joined)
                    #expect(joined == (inline.literal() ?? "<nil>"))
                }
            }
        }
        #expect(pieces == ["first line", "second line", "third line"])
        }
    }

    @Test("literalSegments equals literal() for a fenced code block body")
    func codeBlockBody() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let source = "```\nline one\nline two\n```"
        try MarkdownDocument.withParsedDocument(source) { doc in
        var bodies: [String] = []
        let root = doc.root
        root.children.forEach { block in
            if block.kind.isCodeBlock {
                var bytes: [UInt8] = []
                block.literalSegments().forEach { span in
                    let raw = span.span
                    for i in 0..<raw.count {
                        bytes.append(raw[i])
                    }
                }
                let joined = String(decoding: bytes, as: UTF8.self)
                bodies.append(joined)
                #expect(joined == (block.literal() ?? "<nil>"))
            }
        }
        #expect(bodies == ["line one\nline two\n"])
        }
    }

    @Test("literalSegments is empty for non-literal kinds")
    func emptyForNonLiteral() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let source = "text"
        try MarkdownDocument.withParsedDocument(source) { doc in
        let root = doc.root
        root.children.forEach { paragraph in
            // A paragraph has no literal content of its own.
            let isEmpty = paragraph.literalSegments().isEmpty
            #expect(isEmpty)
        }
        }
    }
}
