// Format a consistent style for thematic breaks.

import Markdown

let source = """
First paragraph.

-----

Second paragraph.

*****
"""

let document = Document(parsing: source)
let thematicBreakCharacter = MarkupFormatter.Options.ThematicBreakCharacter.dash
// Make all thematic breaks 10 dash `-` characters.
let formattingOptions = MarkupFormatter.Options(thematicBreakCharacter: thematicBreakCharacter, thematicBreakLength: 10)
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
