#[[
This source file is part of the Swift System open source project

Copyright (c) 2024 Apple Inc. and the Swift System project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(Markdown
  Base/ChildIndexPath.swift
  Base/DirectiveArgument.swift
  Base/Document.swift
  Base/LiteralMarkup.swift
  Base/Markup.swift
  Base/MarkupChildren.swift
  Base/MarkupData.swift
  Base/PlainTextConvertibleMarkup.swift
  Base/RawMarkup.swift
  "Block Nodes/Block Container Blocks/Doxygen Commands/DoxygenDiscussion.swift"
  "Block Nodes/Block Container Blocks/Doxygen Commands/DoxygenNote.swift"
  "Block Nodes/Block Container Blocks/Doxygen Commands/DoxygenAbstract.swift"
  "Block Nodes/Block Container Blocks/Doxygen Commands/DoxygenParameter.swift"
  "Block Nodes/Block Container Blocks/Doxygen Commands/DoxygenReturns.swift"
  "Block Nodes/Block Container Blocks/BlockDirective.swift"
  "Block Nodes/Block Container Blocks/BlockQuote.swift"
  "Block Nodes/Block Container Blocks/CustomBlock.swift"
  "Block Nodes/Block Container Blocks/ListItem.swift"
  "Block Nodes/Block Container Blocks/OrderedList.swift"
  "Block Nodes/Block Container Blocks/UnorderedList.swift"
  "Block Nodes/Inline Container Blocks/Paragraph.swift"
  "Block Nodes/Leaf Blocks/CodeBlock.swift"
  "Block Nodes/Leaf Blocks/Heading.swift"
  "Block Nodes/Leaf Blocks/HTMLBlock.swift"
  "Block Nodes/Leaf Blocks/ThematicBreak.swift"
  "Block Nodes/Tables/Table.swift"
  "Block Nodes/Tables/TableBody.swift"
  "Block Nodes/Tables/TableCell.swift"
  "Block Nodes/Tables/TableCellContainer.swift"
  "Block Nodes/Tables/TableHead.swift"
  "Block Nodes/Tables/TableRow.swift"
  Infrastructure/Replacement.swift
  Infrastructure/SourceLocation.swift
  "Inline Nodes/Inline Containers/Emphasis.swift"
  "Inline Nodes/Inline Containers/Image.swift"
  "Inline Nodes/Inline Containers/InlineAttributes.swift"
  "Inline Nodes/Inline Containers/Link.swift"
  "Inline Nodes/Inline Containers/Strikethrough.swift"
  "Inline Nodes/Inline Containers/Strong.swift"
  "Inline Nodes/Inline Leaves/CustomInline.swift"
  "Inline Nodes/Inline Leaves/InlineCode.swift"
  "Inline Nodes/Inline Leaves/InlineHTML.swift"
  "Inline Nodes/Inline Leaves/LineBreak.swift"
  "Inline Nodes/Inline Leaves/SoftBreak.swift"
  "Inline Nodes/Inline Leaves/SymbolLink.swift"
  "Inline Nodes/Inline Leaves/Text.swift"
  "Interpretive Nodes/Aside.swift"
  Parser/BlockDirectiveParser.swift
  Parser/CommonMarkConverter.swift
  Parser/LazySplitLines.swift
  Parser/ParseOptions.swift
  Parser/RangeAdjuster.swift
  Parser/RangerTracker.swift
  Rewriter/MarkupRewriter.swift
  "Structural Restrictions/BasicBlockContainer.swift"
  "Structural Restrictions/BasicInlineContainer.swift"
  "Structural Restrictions/BlockContainer.swift"
  "Structural Restrictions/BlockMarkup.swift"
  "Structural Restrictions/InlineContainer.swift"
  "Structural Restrictions/InlineMarkup.swift"
  "Structural Restrictions/ListItemContainer.swift"
  Utility/AtomicCounter.swift
  Utility/CharacterExtensions.swift
  Utility/CollectionExtensions.swift
  Utility/StringExtensions.swift
  Visitor/MarkupVisitor.swift
  Walker/MarkupWalker.swift
  Walker/Walkers/MarkupFormatter.swift
  Walker/Walkers/MarkupTreeDumper.swift)
target_link_libraries(Markdown PRIVATE
  ArgumentParser
  libcmark-gfm
  libcmark-gfm-extensions)
target_link_libraries(Markdown PUBLIC
  CAtomic)
set_target_properties(Markdown PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})

_install_target(Markdown)
set_property(GLOBAL APPEND PROPERTY SWIFT_MARKDOWN_EXPORTS Markdown)
