// Format links that use URLs as their link text into autolinks.

import Markdown

let source = """
This [https://swift.org](https://swift.org) link will become <https://swift.org>
"""

let document = Document(parsing: source)
let formattingOptions = MarkupFormatter.Options(condenseAutolinks: true)
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
