//! Example on how to parse Markdown from string
import Markdown

let source = "Hello world"
let document = Document(parsing: source)
print(document.debugDescription(options: [.printEverything]))