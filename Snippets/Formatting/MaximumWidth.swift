//! Keep lines under a certain length.
import Markdown

let source = """
This is a really, really, really, really, really, really, really, really, really, really, really long line.
"""

let document = Document(parsing: source)
let lineLimit = MarkupFormatter.Options.PreferredLineLimit(maxLength: 80, breakWith: .softBreak)
let formattingOptions = MarkupFormatter.Options(preferredLineLimit: lineLimit)
let newSource = document.format(options: formattingOptions)

// MARK: Hide

print("## Original source:")
print("```")
print(source)
print("```")
print()

print("## Formatted source:")
print("```")
print(newSource)
print("```")
print()
