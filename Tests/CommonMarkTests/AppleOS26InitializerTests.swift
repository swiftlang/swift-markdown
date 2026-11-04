/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import CommonMark

/// Coverage for the `@available(anyAppleOS 26)` returning initializers (`init(parsing: String)` and `init(parsing: UTF8Span)`) and the `UTF8Span`-returning `source` accessor. These are the zero-copy borrowing entry points that only exist where `UTF8Span` does (OS 26+); the always-available `withParsedDocument` path is covered pervasively elsewhere. Each test guards on availability so it runs on new-enough hosts and is a no-op on older ones.
@Suite("anyAppleOS 26 initializers")
struct AppleOS26InitializerTests {

    @Test("returning String initializer parses the expected tree")
    func stringInitializer() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let source = "# Title\n\nA paragraph with *emphasis*."
        let doc = try MarkdownDocument(parsing: source)
        let kinds = dfs(doc).map { $0.kind }
        #expect(kinds.first == .document)
        #expect(kinds.contains(.heading(level: 1)))
        #expect(kinds.contains(.paragraph))
        #expect(kinds.contains(.emphasis))
    }

    @Test("UTF8Span initializer parses the same tree as the String initializer")
    func utf8SpanInitializer() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let source = "one `code` two"
        let viaString = try MarkdownDocument(parsing: source)
        let stringKinds = dfs(viaString).map { $0.kind }
        let viaSpan = try MarkdownDocument(parsing: source.utf8Span)
        let spanKinds = dfs(viaSpan).map { $0.kind }
        #expect(spanKinds == stringKinds)
        #expect(spanKinds.contains(where: { if case .codeInline = $0 { true } else { false } }))
    }

    @Test("source accessor round-trips the original bytes (incl. multi-byte scalars)")
    func sourceAccessorRoundTrips() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else { return }
        let source = "l\u{ED}ne one\nline two"   // `í` is a 2-byte scalar
        let doc = try MarkdownDocument(parsing: source)
        #expect(String(copying: doc.source) == source)
    }
}
