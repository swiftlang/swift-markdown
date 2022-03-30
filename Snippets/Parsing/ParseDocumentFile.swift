//! Parse the contents of a file by its ``URL`` without having to read
//! its contents yourself.

import Foundation
import Markdown

let file = URL(fileURLWithPath: "test.md")
let document = try Document(parsing: file)

// MARK: HIDE

print("Parsed \(file.path)")
print("## Parsed document structure")
print(document.debugDescription())
