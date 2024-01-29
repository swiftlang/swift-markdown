#[[
This source file is part of the Swift System open source project

Copyright (c) 2024 Apple Inc. and the Swift System project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(CAtomic STATIC
  CAtomic.c)
target_include_directories(CAtomic PUBLIC
  include)

set_property(GLOBAL APPEND PROPERTY SWIFT_MARKDOWN_EXPORTS CAtomic)
