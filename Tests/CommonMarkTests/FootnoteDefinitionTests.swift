/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

@Suite("Footnote Definition Tests")
struct FootnoteDefinitionTests {

    /// A footnote definition whose paragraph content is *materialized* into the strings arena rather than left as a source range. CRLF line endings force the multi-line join to materialize (the contiguity fast path only keeps single-`\n`, source-adjacent runs lazy), so the content chunk handed to footnote-def detection has `inSource == false`.
    ///
    /// `wrapInFootnoteDefinition` must not `assert(label.inSource)` and then read the label from `sourceBytes` unconditionally - for materialized content that's a debug trap (and, in release, a garbage `footnoteMap` key read from source bytes at strings offsets). This input is valid CommonMark, so the parser must register the definition from the correct buffer and let the reference resolve against it.
    @Test("footnote definition with materialized (CRLF) content registers and resolves")
    func materializedFootnoteDefinitionResolves() throws {
        // CRLF between the definition's two lines forces materialization of the def's content.
        let source = "[^a]: first line\r\nsecond line\n\nsee [^a]\n"
        try MarkdownDocument.withParsedDocument(source, options: [.footnotes]) { doc in

        var defLabel: String? = nil
        var refLabel: String? = nil
        var refIndex: Int? = nil

        let root = doc.root
        root.children.forEach { block in
            if block.kind == .footnoteDefinition {
                defLabel = block.footnoteLabel()
            }
            block.children.forEach { inline in
                if case .footnoteReference(let index) = inline.kind {
                    refLabel = inline.footnoteLabel()
                    refIndex = index
                }
            }
        }

        #expect(defLabel == "a")
        #expect(refLabel == "a")
        #expect(refIndex == 1)
        }
    }
}
