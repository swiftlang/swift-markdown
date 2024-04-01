// Replace some text with a ``MarkupRewriter``.
//
// > Experiment: You can use a similar approach for other kinds of replacements.
// > Try updating link destinations in your document by implementing
// > a `visitLink` method and returning a new ``Link`` element.

import Markdown

struct TextReplacer: MarkupRewriter {
    var target: String
    var replacement: String

    init(replacing target: String, with replacement: String?) {
        precondition(!target.isEmpty)
        self.target = target
        self.replacement = replacement ?? ""
    }

    func visitText(_ text: Text) -> Markup? {
        return Text(text.string.replacingOccurrences(of: target, with: replacement))
    }
}

let source = """
The word "foo" will be replaced with "bar".
"""
let document = Document(parsing: source)
var replacer = TextReplacer(replacing: "foo", with: "bar")
let newDocument = replacer.visit(document) as! Document

print("""
## Original Markdown structure:
\(document.debugDescription())

## New Markdown structure:
\(newDocument.debugDescription())
""")
// snippet.hide
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
