# Snippets

## Parsing

Parse strings in memory or files on disk into a structured ``Markup`` tree.

@Snippet(path: "swift-markdown/Snippets/Parsing/ParseDocumentString")
@Snippet(path: "swift-markdown/Snippets/Parsing/ParseDocumentFile")

## Querying

@Snippet(path: "swift-markdown/Snippets/Querying/ChildThrough")

## Walkers, Rewriters, and Visitors

Use ``MarkupWalker`` to collect information about ``Markup`` trees without modifying their contents.

@Snippet(path: "swift-markdown/Snippets/Walkers/LinkCollector")

Use ``MarkupRewriter`` to programmatically change the structure and contents of ``Markup`` trees.

@Snippet(path: "swift-markdown/Snippets/Rewriters/RemoveElementKind")
@Snippet(path: "swift-markdown/Snippets/Rewriters/ReplaceText")

Use ``MarkupVisitor`` to convert a ``Markup`` tree to another nested structure.

@Snippet(path: "swift-markdown/Snippets/Visitors/XMLConverter")

## Formatting

Use the following formatting options alone or in combination to format
a Markdown document to a consistent, preferred style.

@Snippet(path: "swift-markdown/Snippets/Formatting/DefaultFormatting")
@Snippet(path: "swift-markdown/Snippets/Formatting/MaximumWidth")
@Snippet(path: "swift-markdown/Snippets/Formatting/CondenseAutolinks")
@Snippet(path: "swift-markdown/Snippets/Formatting/CustomLinePrefix")
@Snippet(path: "swift-markdown/Snippets/Formatting/EmphasisMarkers")
@Snippet(path: "swift-markdown/Snippets/Formatting/OrderedListNumerals")
@Snippet(path: "swift-markdown/Snippets/Formatting/UnorderedListMarker")
@Snippet(path: "swift-markdown/Snippets/Formatting/PreferredHeadingStyle")
@Snippet(path: "swift-markdown/Snippets/Formatting/ThematicBreakCharacter")
@Snippet(path: "swift-markdown/Snippets/Formatting/UseCodeFence")

<!-- Copyright (c) 2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
