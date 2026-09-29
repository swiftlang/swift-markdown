/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

@Suite("Content projection prototype")
struct NodeContentTests {

    @Test("link content in one switch - single-segment spans")
    func linkContent() throws {
        if #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) {
            let source = "[text](/url \"title\")"
            try MarkdownDocument.withParsedDocument(source) { doc in
            var url: String?
            var title: String?
            func walk(_ node: borrowing MarkdownNode) {
                switch node.content {
                case .link(let u, let t):
                    url = String(copying: u)
                    title = String(copying: t)
                default:
                    break
                }
                node.children.forEach { walk($0) }
            }
            walk(doc.root)
            #expect(url == "/url")
            #expect(title == "title")
            }
        }
    }

    @Test("code block body is vended as multi-segment, not a materialized span")
    func codeBlockContent() throws {
        if #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) {
            let source = "```swift\na\nb\n```\n"
            try MarkdownDocument.withParsedDocument(source) { doc in
            var info: String?
            var bodyJoined = ""
            var segmentCount = 0
            func walk(_ node: borrowing MarkdownNode) {
                switch node.content {
                case .codeBlock(let i, let body):
                    info = String(copying: i)
                    segmentCount = body.count
                    body.forEach { span in bodyJoined += String(copying: span) }
                default:
                    break
                }
                node.children.forEach { walk($0) }
            }
            walk(doc.root)
            #expect(info == "swift")
            #expect(bodyJoined == "a\nb\n")
            #expect(segmentCount > 1)   // proves the body stays segmented (zero-copy), not collapsed to one span
            }
        }
    }

    @Test("inline text content via content")
    func textContent() throws {
        if #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) {
            let source = "hello"
            try MarkdownDocument.withParsedDocument(source) { doc in
            var text: String?
            func walk(_ node: borrowing MarkdownNode) {
                switch node.content {
                case .text(let segments):
                    var joined = ""
                    segments.forEach { span in joined += String(copying: span) }
                    text = joined
                default:
                    break
                }
                node.children.forEach { walk($0) }
            }
            walk(doc.root)
            #expect(text == "hello")
            }
        }
    }
}
