#[[
This source file is part of the Swift System open source project

Copyright (c) 2024 Apple Inc. and the Swift System project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

set(SWIFT_MARKDOWN_EXPORTS_FILE
  ${CMAKE_CURRENT_BINARY_DIR}/SwiftMarkdownExports.cmake)

configure_file(SwiftMarkdownConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/SwiftMarkdownConfig.cmake)

get_property(SWIFT_MARKDOWN_EXPORTS GLOBAL PROPERTY SWIFT_MARKDOWN_EXPORTS)
export(TARGETS ${SWIFT_MARKDOWN_EXPORTS}
  NAMESPACE SwiftMarkdown::
  FILE ${SWIFT_MARKDOWN_EXPORTS_FILE}
  EXPORT_LINK_INTERFACE_LIBRARIES)
