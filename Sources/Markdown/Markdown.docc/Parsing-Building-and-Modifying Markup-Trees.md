# Parsing, Building, and Modifying Markup Trees

Get started with Swift-Markdown's markup trees.

## Parsing

To create a new ``Document`` by parsing markdown content, use Document's ``Document/init(parsing:options:)`` initializer, supplying a `String` or `URL`:

```swift
import Markdown

let source = "This is a markup *document*."
let document = Document(parsing: source)
print(document.debugDescription())
// Document
// └─ Paragraph
//    ├─ Text "This is a markup "
//    ├─ Emphasis
//    │  └─ Text "document"
//    └─ Text "."
```

Parsing text is just one way to build a tree of ``Markup`` elements. You can also build them yourself declaratively.

## Building Markup Trees

You can build trees using initializers for the various element types provided.

```swift
import Markdown

let document = Document(
    Paragraph(
        Text("This is a "),
        Emphasis(
            Text("paragraph."))))
```

This would be equivalent to parsing `"This is a *paragraph.*"` but allows you to programmatically insert content from other data sources into individual elements.

## Modifying Markup Trees with Persistence

Swift Markdown uses a [persistent](https://en.wikipedia.org/wiki/Persistent_data_structure) tree for its backing storage, providing effectively immutable, copy-on-write value types that only copy the substructure necessary to create a unique root without affecting the previous version of the tree.

### Modifying Elements Directly

If you just need to make a quick change, you can modify an element anywhere in a tree, and Swift Markdown will create copies of substructure that cannot be shared.

```swift
import Markdown

let source = "This is *emphasized.*"
let document = Document(parsing: source)
print(document.debugDescription())
// Document
// └─ Paragraph
//    ├─ Text "This is "
//    └─ Emphasis
//       └─ Text "emphasized."

var text = document.child(through:
    0, // Paragraph
    1, // Emphasis
    0) as! Text // Text

text.string = "really emphasized!"
print(text.root.debugDescription())
// Document
// └─ Paragraph
//    ├─ Text "This is "
//    └─ Emphasis
//       └─ Text "really emphasized!"

// The original document is unchanged:

print(document.debugDescription())
// Document
// └─ Paragraph
//    ├─ Text "This is "
//    └─ Emphasis
//       └─ Text "emphasized."
```

If you find yourself needing to systematically change many parts of a tree, or even provide a complete transformation into something else, maybe the familiar [Visitor Pattern](https://en.wikipedia.org/wiki/Visitor_pattern) is what you want.

<!-- Copyright (c) 2021-2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
