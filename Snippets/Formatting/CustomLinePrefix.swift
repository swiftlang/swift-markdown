// Format a Markdown document to have a custom line prefix, such as a comment prefix for use in source code.

import Markdown

let source = """
This document's lines
will be prefixed with `//`.
"""

let document = Document(parsing: source)
let formattingOptions = MarkupFormatter.Options(customLinePrefix: "// ")
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
