// Find a matching element deep within a ``Markup`` tree.

import Markdown

let source = """
Reach into a document to find the *emphasized text*.
"""
let document = Document(parsing: source)
let emphasizedText = document.child(through: [
    (0, Paragraph.self),
    (1, Emphasis.self),
    (0, Text.self)
]) as! Text

print("""
## Document structure:
\(document.debugDescription())

## Found element:
\(emphasizedText.detachedFromParent.debugDescription())
""")
// snippet.hide
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
