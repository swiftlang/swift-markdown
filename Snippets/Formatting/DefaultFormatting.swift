// Format Markdown with the default settings.

import Markdown

let source = """
|a|b|c|
|-|:-|-:|
|*Some text*|x|<https://swift.org>|
"""

// There is not an option for formatting tables per se but is useful to show the behavior for tables.
// Table columns are automatically expanded to fit the column's largest
// cell, making the table easier to read in the Markdown source.

let document = Document(parsing: source)
let formattedSource = document.format()

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
