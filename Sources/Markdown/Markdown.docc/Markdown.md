# ``Markdown``

Swift `Markdown` is a Swift package for parsing, building, editing, and analyzing Markdown documents.

## Overview

The parser is powered by GitHub-flavored Markdown's [cmark-gfm](https://github.com/github/cmark-gfm) implementation, so it follows the spec closely. As the needs of the community change, the effective dialect implemented by this library may change.

The markup tree provided by this package is comprised of immutable/persistent, thread-safe, copy-on-write value types that only copy substructure that has changed. Other examples of the main strategy behind this library can be seen in Swift's [lib/Syntax](https://github.com/apple/swift/tree/master/lib/Syntax) and its Swift bindings, [SwiftSyntax](https://github.com/apple/swift-syntax).

## Topics 

### Essentials

- ``Markup``
- ``MarkupChildren``
- ``ChildIndexPath``
- ``TypedChildIndexPath``
- ``DirectiveArgument``
- ``DirectiveArgumentText``
- ``Document``
- ``LiteralMarkup``
- ``PlainTextConvertibleMarkup``

### Markup Types

- <doc:BlockMarkup>
- <doc:InlineMarkup>
- ``Aside``

### Infrastructure

- <doc:Infrastructure> 

### Visit Markup

- <doc:VisitMarkup> 
- <doc:FormatterAndOptions>
