# Swift Markdown

Swift `Markdown` is a Swift package for parsing, building, editing, and analyzing Markdown documents.

The parser is powered by GitHub-flavored Markdown's [cmark-gfm](https://github.com/github/cmark-gfm) implementation, so it follows the spec closely. As the needs of the community change, the effective dialect implemented by this library may change.

The markup tree provided by this package is comprised of immutable/persistent, thread-safe, copy-on-write value types that only copy substructure that has changed. Other examples of the main strategy behind this library can be seen in [SwiftSyntax](https://github.com/apple/swift-syntax).

## Getting Started Using Markup

In your `Package.swift` Swift Package Manager manifest, add the following dependency to your `dependencies` argument:

```swift
.package(url: "https://github.com/apple/swift-markdown.git", .branch("main")),
```

Add the dependency to any targets you've declared in your manifest:

```swift
.target(name: "MyTarget", dependencies: ["Markdown"]),
```

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

Please see Swift `Markdown`'s [documentation site](https://apple.github.io/swift-markdown/documentation/markdown/)
for more detailed information about the library.

## Getting Involved

### Submitting a Bug Report

Swift Markdown tracks all bug reports with [GitHub Issues](https://github.com/apple/swift-markdown/issues).
You can use the "Swift-Markdown" component for issues and feature requests specific to Swift Markdown.
When you submit a bug report we ask that you follow the
Swift [Bug Reporting](https://swift.org/contributing/#reporting-bugs) guidelines
and provide as many details as possible.

### Submitting a Feature Request

For feature requests, please feel free to file a [GitHub issue](https://github.com/apple/swift-markdown/issues/new)
or start a discussion on the [Swift Forums](https://forums.swift.org/c/development/swift-docc).

Don't hesitate to submit a feature request if you see a way
Swift Markdown can be improved to better meet your needs.

### Contributing to Swift Markdown

Please see the [contributing guide](https://swift.org/contributing/#contributing-code) for more information.

<!-- Copyright (c) 2021-2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
