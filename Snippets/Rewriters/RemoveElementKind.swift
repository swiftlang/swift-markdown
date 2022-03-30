//! Remove all instances of a kind of element using a `MarkupRewriter`.
import Markdown

// MARK: Hide

let source = """
The strong emphasis element is **going to be** deleted.
"""

// MARK: Show

struct StrongDeleter: MarkupRewriter {
  func visitStrong(_ strong: Strong) -> Markup? {
    return nil
  }
}

let document = Document(parsing: source)
var deleter = StrongDeleter()
let newDocument = deleter.visit(document) as! Document

// MARK: Hide

print("## Original source:")
print("```")
print(source)
print("```")
print()

print("## Original Markdown tree:")
print(document.debugDescription())
print()

print("## New Markdown tree:")
print(newDocument.debugDescription())
print()

print("## New source:")
print("```")
print(newDocument.format())
print("```")
