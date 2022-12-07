// Format the unordered list marker.

import Markdown

let source = """
- An
- unordered
- list
"""

let document = Document(parsing: source)
// Use an star or asterisk `*` as the unordered list marker.
let formattedSource = document.format(options: .init(unorderedListMarker: .star))

print("""
## Original source:
\(source)

## Formatted source:
\(formattedSource)
""")
// snippet.hide
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
