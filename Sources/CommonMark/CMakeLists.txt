#[[
This source file is part of the Swift System open source project

Copyright (c) 2024 Apple Inc. and the Swift System project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(CommonMark
  Internal/Arena/Chunk.swift
  Internal/Arena/DocumentStorage.swift
  Internal/Arena/NodeImplementation.swift
  Internal/Arena/Segment.swift
  Internal/Arena/StorageView.swift
  Internal/Parser/ASCIIByte.swift
  Internal/Parser/BlockParser.swift
  Internal/Parser/ContentSpan.swift
  Internal/Parser/Entities.swift
  Internal/Parser/EntityParser.swift
  Internal/Parser/InlineParser.swift
  Internal/Parser/LineReader.swift
  Internal/Parser/Scanners.swift
  Internal/Parser/TableParser.swift
  Public/MarkdownDocument.swift
  Public/MarkdownNode.swift
  Public/NodeContent.swift
  Public/ParseOptions.swift)

target_compile_options(CommonMark PRIVATE
  "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-swift-version 6>"
  "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-enable-upcoming-feature ApproachableConcurrency>"
  "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-enable-experimental-feature LifetimeDependence>"
  "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-enable-experimental-feature Lifetimes>"
  "$<$<COMPILE_LANGUAGE:Swift>:-enable-library-evolution>")

# `_SM_BASIC_CONTAINERS` is set by the root CMakeLists to whichever swift-collections target name is available (namespaced `SwiftCollections::BasicContainers` from find_package, or the plain `BasicContainers` from a source build).
target_link_libraries(CommonMark PRIVATE
  ${_SM_BASIC_CONTAINERS})
set_target_properties(CommonMark PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})

_install_target(CommonMark)
set_property(GLOBAL APPEND PROPERTY SWIFT_MARKDOWN_EXPORTS CommonMark)
