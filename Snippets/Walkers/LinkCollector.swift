// Collect all links in a Markdown document.

import Markdown

struct LinkCollector: MarkupWalker {
  var links = [String]()
  mutating func visitLink(_ link: Link) {
    link.destination.map { links.append($0) }
  }
}

let source = """
A link to a [non-existent website](https://iqnvodkfjd.com).

A link to a missing resource at <https://www.swift.org/what>.

A valid link to <https://www.swift.org>.
"""
let document = Document(parsing: source)
// snippet.hide
print("## Checking links in parsed document:")
print(document.debugDescription())
// snippet.show
var linkCollector = LinkCollector()
linkCollector.visit(document)
print("## Found links:")
print(linkCollector.links.joined(separator: "\n"))
// snippet.hide
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
