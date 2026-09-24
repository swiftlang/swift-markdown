#[[
This source file is part of the Swift System open source project

Copyright (c) 2024 Apple Inc. and the Swift System project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

set(SWIFT_MARKDOWN_EXPORTS_FILE
  ${CMAKE_CURRENT_BINARY_DIR}/SwiftMarkdownExports.cmake)

get_property(SWIFT_MARKDOWN_EXPORTS GLOBAL PROPERTY SWIFT_MARKDOWN_EXPORTS)
# Only emit a build-tree export when SwiftMarkdown is the top-level project
# built against an installed cmark-gfm.
# When SwiftMarkdown is pulled in as a subproject (e.g. via FetchContent), the
# consumer references its targets directly, and the exported interface would
# otherwise drag in transitive targets (such as libcmark-gfm-extensions) that
# are not part of this build tree's export set.
if(PROJECT_NAME STREQUAL CMAKE_PROJECT_NAME AND cmark-gfm_FOUND)
  configure_file(SwiftMarkdownConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/SwiftMarkdownConfig.cmake)
  export(TARGETS ${SWIFT_MARKDOWN_EXPORTS}
    NAMESPACE SwiftMarkdown::
    FILE ${SWIFT_MARKDOWN_EXPORTS_FILE}
    EXPORT_LINK_INTERFACE_LIBRARIES)
endif()
