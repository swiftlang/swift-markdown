// Implement a ``MarkupVisitor`` to transform a ``Markup`` tree
// to another structured data format such as XML.
//
// > Note: This is not a complete example converting
// > the unique and important properties of each kind of ``Markup`` element
// > as XML attributes.
//
// > Experiment: Implement all visitor methods for each type
// > for a more complete XML or HTML converter.

import Markdown

struct XMLConverter: MarkupVisitor {
    mutating func defaultVisit(_ markup: Markup) -> XML {
        return XML(tag: String(describing: type(of: markup)),
                   children: markup.children.map { defaultVisit($0) },
                   text: (markup as? Text).map { $0.string })
    }
}

let source = """
A ***basic*** document.
"""
let document = Document(parsing: source)
var xmlConverter = XMLConverter()
let xml = xmlConverter.visit(document)

print("""
## Original document structure:
\(document.debugDescription())

## Resulting XML:
\(xml.format())
""")

// A very basic XML tree type.
struct XML {
  var tag: String
  var children: [XML]
  var text: String?

  func format(indent: Int = 0) -> String {
    let indentation = String(repeating: " ", count: indent)
    if tag == "Text" {
      return "\(indentation)<\(tag)>\(text ?? "")</\(tag)>"
    } else {
      var result = "\(indentation)<\(tag)>"
      for child in children {
        result += "\n\(child.format(indent: indent + 2))"
      }
      result += "\n\(indentation)<\(tag)>"
      return result
    }
  }
}

// snippet.hide
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
