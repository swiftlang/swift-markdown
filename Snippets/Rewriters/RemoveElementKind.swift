// Remove all instances of a kind of element using a `MarkupRewriter`.

import Markdown

let source = """
The strong emphasis element is **going to be** deleted.
"""

struct StrongDeleter: MarkupRewriter {
  // Delete all ``Strong`` elements.
  func visitStrong(_ strong: Strong) -> Markup? {
    return nil
  }
}

let document = Document(parsing: source)
var deleter = StrongDeleter()
let newDocument = deleter.visit(document) as! Document

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
