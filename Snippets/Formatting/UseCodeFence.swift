// Format all code blocks to use a consistent style for code blocks,
// optionally setting the default info string to declare that they
// have a particular syntax.

import Markdown

let source = """
This document contains a mix of indented and fenced code blocks.

    A code block.

```
func foo() {}
```
"""

let document = Document(parsing: source)
// Always fenced code blocks.
let fencedCodeBlock = MarkupFormatter.Options.UseCodeFence.always
// Use `swift` as the info string on all fenced code blocks.
let defaultCodeBlockLanguage = "swift"
let formattedSource = document.format(options: .init(useCodeFence: fencedCodeBlock, defaultCodeBlockLanguage: defaultCodeBlockLanguage))

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
