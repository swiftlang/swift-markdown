// Format the counting behavior of ordered lists.

import Markdown

let source = """
1. An
2. ordered
3. list
"""

let document = Document(parsing: source)
// Use all 0. markers to allow easily reordering ordered list items.
let formattingOptions = MarkupFormatter.Options(orderedListNumerals: .allSame(1))
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
