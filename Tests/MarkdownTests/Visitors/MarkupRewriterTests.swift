/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

/// A `Document` that has every kind of element in it at least once.
let everythingDocument = Document(parsing: try! String(contentsOf: Bundle.module.url(forResource: "Everything", withExtension: "md")!))


class MarkupRewriterTests: XCTestCase {
    /// Tests that a rewriter which makes no modifications results in the same document
    func testNullRewriter() {
        /// A MarkupRewriter that leaves the tree unchanged
        struct NullMarkupRewriter : MarkupRewriter {}

        var nullRewriter = NullMarkupRewriter()
        // FIXME: Workaround for rdar://problem/47686212
        let markup = everythingDocument
        let shouldBeSame = nullRewriter.visit(markup) as! Document
        try! markup.debugDescription().write(to: .init(fileURLWithPath: "/tmp/old.txt"), atomically: true, encoding: .utf8)
        try! shouldBeSame.debugDescription().write(to: .init(fileURLWithPath: "/tmp/new.txt"), atomically: true, encoding: .utf8)
        XCTAssertEqual(markup.debugDescription(), shouldBeSame.debugDescription())
    }

    /// Tests that a particular kind of element can be deleted
    func funcTestDeleteEveryOccurrence() {
        struct StrongDeleter: MarkupRewriter {
            mutating func visitStrong(_ strong: Strong) -> Markup? {
                return nil
            }
        }

        struct StrongCollector: MarkupWalker {
            var strongCount = 0
            mutating func visitStrong(_ strong: Strong) {
                strongCount += 1
                defaultVisit(strong)
            }
        }
        
        // FIXME: Workaround for rdar://problem/47686212
        let markup = everythingDocument

        var strongCollector = StrongCollector()
        strongCollector.visit(markup)
        let originalStrongCount = strongCollector.strongCount
        XCTAssertEqual(1, originalStrongCount)

        var strongDeleter = StrongDeleter()
        let markupWithoutStrongs = strongDeleter.visit(markup)!
        strongCollector.strongCount = 0
        strongCollector.visit(markupWithoutStrongs)
        let newStrongCount = strongCollector.strongCount
        XCTAssertEqual(0, newStrongCount)
    }

    /// Tests that all elements of a particular kind are visited and rewritten no matter where in the three.
    func testSpecificKindRewrittenEverywhere() {
        /// Replaces every `Text` markup element with its uppercased equivalent.
        struct UppercaseText: MarkupRewriter {
            mutating func visitText(_ text: Text) -> Markup? {
                var newText = text
                newText.string = text.string.uppercased()
                return newText
            }
        }

        /// Collects and concatenates all `Text` elements' markup into a single string for later test comparison.
        struct CollectText: MarkupWalker {
            var result = ""
            mutating func visitText(_ text: Text) {
                result += text.string
            }
        }
        
        // FIXME: Workaround for rdar://problem/47686212
        let markup = everythingDocument

        // Combine the text from the original test markup file
        var originalTextCollector = CollectText()
        originalTextCollector.visit(markup)
        let originalText = originalTextCollector.result

        // Create a version of the test markup document with all text elements uppercased.
        var uppercaser = UppercaseText()
        let uppercased = uppercaser.visit(markup)!

        // Combine the text from the uppercased markup document
        var uppercaseTextCollector = CollectText()
        uppercaseTextCollector.visit(uppercased)
        let uppercasedText = uppercaseTextCollector.result

        XCTAssertEqual(originalText.uppercased(), uppercasedText)
    }
}
