// Format a consistent style for emphasis markers.

import Markdown

let source = """
This document uses a mix of *star* and _underbar_ emphasized elements.
"""

let document = Document(parsing: source)
// Use only * for emphasis markers.
let emphasisMarker = MarkupFormatter.Options.EmphasisMarker.star
let formattedSource = document.format(options: .init(emphasisMarker: emphasisMarker))

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
