//! Format a parsed Markdown document with default settings.

import Markdown

let source = """
|a|b|c|
|-|-|-|
|*Some text*||<https://swift.org>|
"""

let document = Document(parsing: source)
let formattedSource = document.format()

// MARK: Hide

print("""
## Original source:
```
\(source)
```
""")

print("""
## Formatted source:
```
\(formattedSource)
```
""")
