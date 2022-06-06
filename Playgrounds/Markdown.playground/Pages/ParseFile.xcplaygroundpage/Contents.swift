//: [Previous](@previous)

import Markdown
import Foundation

let url = Bundle.main.url(forResource: "Test", withExtension: "md")!
let source = try! String(contentsOf: url)
let everythingDocument = Document(parsing: source)
let document = Document(parsing: source)
document.debugDescription(options: [.printEverything])
