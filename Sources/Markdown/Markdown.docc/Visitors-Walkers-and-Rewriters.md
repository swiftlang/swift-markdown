# Visitors, Walkers, and Rewriters

Use `MarkupVisitor` to transform, walk, and rewrite markup trees.

## Markup Visitor

The core ``MarkupVisitor`` protocol provides the basis for transforming, walking, or rewriting a markup tree.

```swift
public protocol MarkupVisitor {
    associatedtype Result
}
```

Using its ``MarkupVisitor/Result`` type, you can transform a markup tree into anything: another markup tree, or perhaps a tree of XML or HTML elements. There are two included refinements of `MarkupVisitor` for common uses.

## Markup Walker

The first refinement of `MarkupVisitor`, ``MarkupWalker``, has an associated `Result` type of `Void`, so it's meant for summarizing or detecting aspects of a markup tree. If you wanted to append to a string as elements are visited, this might be a good tool for that.

```swift
import Markdown

/// Counts `Link`s in a `Document`.
struct LinkCounter: MarkupWalker {
    var count = 0
    mutating func visitLink(_ link: Link) {
        if link.destination == "https://swift.org" {
            count += 1
        }
        descendInto(link)
    }
}

let source = "There are [two](https://swift.org) links to <https://swift.org> here."
let document = Document(parsing: source)
print(document.debugDescription())
var linkCounter = LinkCounter()
linkCounter.visit(document)
print(linkCounter.count)
// 2
```

## Markup Rewriter

The second refinement, ``MarkupRewriter``, has an associated `Result` type of an optional ``Markup`` element, so it's meant to change or even remove elements from a markup tree. You can return `nil` to delete an element, or return another element to substitute in its place.

```swift
import Markdown

/// Delete all **strong** elements in a markup tree.
struct StrongDeleter: MarkupRewriter {
    mutating func visitStrong(_ strong: Strong) -> Markup? {
        return nil
    }
}

let source = "Now you see me, **now you don't**"
let document = Document(parsing: source)
var strongDeleter = StrongDeleter()
let newDocument = strongDeleter.visit(document)

print(newDocument!.debugDescription())
// Document
// └─ Paragraph
//    └─ Text "Now you see me, "
```

<!-- Copyright (c) 2021-2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
