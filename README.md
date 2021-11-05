# Swift Markdown

Swift `Markdown` is a Swift package for parsing, building, editing, and analyzing Markdown documents.

The parser is powered by GitHub-flavored Markdown's [cmark-gfm](https://github.com/github/cmark-gfm) implementation, so it follows the spec closely. As the needs of the community change, the effective dialect implemented by this library may change.

The markup tree provided by this package is comprised of immutable/persistent, thread-safe, copy-on-write value types that only copy substructure that has changed. Other examples of the main strategy behind this library can be seen in Swift's [lib/Syntax](https://github.com/apple/swift/tree/master/lib/Syntax) and its Swift bindings, [SwiftSyntax](https://github.com/apple/swift-syntax).

## Getting Started Using Markup

In your `Package.swift` Swift Package Manager manifest, add the following dependency to your `dependencies` argument:

```swift
.package(url: "ssh://git@github.com/apple/swift-markdown.git", .branch("main")),
```

Add the dependency to any targets you've declared in your manifest:

```swift
.target(name: "MyTarget", dependencies: ["Markdown"]),
```

## Parsing

To parse a document, use `Document(parsing:)`, supplying a `String` or `URL`:

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

Parsing text is just one way to build a tree of `Markup` elements. You can also build them yourself declaratively.

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

## Visitors, Walkers, and Rewriters

There is a core `MarkupVisitor` protocol that provides the basis for transforming, walking, or rewriting a markup tree.

```swift
public protocol MarkupVisitor {
    associatedtype Result
}
```

Using its `Result` type, you can transform a markup tree into anything: another markup tree, or perhaps a tree of XML or HTML elements. There are two included refinements of `MarkupVisitor` for common uses.

The first refinement, `MarkupWalker`, has an associated `Result` type of `Void`, so it's meant for summarizing or detecting aspects of a markup tree. If you wanted to append to a string as elements are visited, this might be a good tool for that.

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

The second refinement, `MarkupRewriter`, has an associated `Result` type of `Markup?`, so it's meant to change or even remove elements from a markup tree. You can return `nil` to delete an element, or return another element to substitute in its place.

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

## Block Directives

Swift Markdown includes a syntax extension for attributed block elements. See [Block Directive](Documentation/BlockDirectives.md) documentation for more information.

## Getting Involved

### Submitting a Bug Report

Swift Markdown tracks all bug reports with [Swift JIRA](https://bugs.swift.org/).
You can use the "Swift-Markdown" component for issues and feature requests specific to Swift Markdown.
When you submit a bug report we ask that you follow the
Swift [Bug Reporting](https://swift.org/contributing/#reporting-bugs) guidelines
and provide as many details as possible.

### Submitting a Feature Request

For feature requests, please feel free to create an issue
on [Swift JIRA](https://bugs.swift.org/) with the `New Feature` type
or start a discussion on the [Swift Forums](https://forums.swift.org/c/development/swift-docc).

Don't hesitate to submit a feature request if you see a way
Swift Markdown can be improved to better meet your needs.

### Contributing to Swift Markdown

Please see the [contributing guide](https://swift.org/contributing/#contributing-code) for more information.

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
