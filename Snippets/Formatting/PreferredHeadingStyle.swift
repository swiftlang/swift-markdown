// Format a Markdown document to use ATX style headings throughout.

import Markdown

let source = """
# Title

## Second-level Heading

Another Second-level Heading
----------------------------

The above heading will be converted to ATX style, using hashes.
"""

let document = Document(parsing: source)
let headingStyle = MarkupFormatter.Options.PreferredHeadingStyle.atx
let formattingOptions = MarkupFormatter.Options(preferredHeadingStyle: headingStyle)
let formattedSource = document.format(options: formattingOptions)

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
