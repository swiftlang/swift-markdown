// Parse a ``String`` as Markdown

import Markdown

let source = "Some *Markdown* source"
let document = Document(parsing: source)

// MARK: HIDE

print("Parsed \(source.debugDescription)")
print("## Parsed document structure")
print(document.debugDescription())
