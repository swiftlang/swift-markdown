// Format lines to stay under a certain length.

import Markdown

let source = """
This is a really, really, really, really, really, really, really, really, really, really, really long line.
"""

let document = Document(parsing: source)
// Break lines longer than 80 characters in width with a soft break.
let lineLimit = MarkupFormatter.Options.PreferredLineLimit(maxLength: 80, breakWith: .softBreak)
let formattingOptions = MarkupFormatter.Options(preferredLineLimit: lineLimit)
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
