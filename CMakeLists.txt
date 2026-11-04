#[[
This source file is part of the Swift System open source project

Copyright (c) 2024 Apple Inc. and the Swift System project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

cmake_minimum_required(VERSION 3.29)

if(POLICY CMP0077)
  cmake_policy(SET CMP0077 NEW)
endif()

if(POLICY CMP0091)
  cmake_policy(SET CMP0091 NEW)
endif()

project(SwiftMarkdown
  LANGUAGES C Swift)

list(APPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake/modules)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)
set(CMAKE_Swift_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)

include(FetchContent)
include(SwiftSupport)

set(_SM_VENDOR_DEPENDENCIES)

set(BUILD_EXAMPLES NO)
set(BUILD_TESTING NO)

# swift-collections provides the BasicContainers module that the CommonMark parser links against.
# Prefer a pre-built package (e.g. one supplied by the Swift toolchain) and only fetch + build from
# source as a fallback, matching this project's dependency-acquisition idiom. Build it multi-module
# (do NOT set COLLECTIONS_SINGLE_MODULE — that folds BasicContainers into a single `Collections`
# module and breaks `import BasicContainers`).
find_package(SwiftCollections CONFIG)
if(NOT SwiftCollections_FOUND)
  FetchContent_Declare(SwiftCollections
    GIT_REPOSITORY https://github.com/apple/swift-collections.git
    GIT_TAG 1.6.0)
  list(APPEND _SM_VENDOR_DEPENDENCIES SwiftCollections)
endif()

if(_SM_VENDOR_DEPENDENCIES)
  FetchContent_MakeAvailable(${_SM_VENDOR_DEPENDENCIES})
endif()

# `find_package` exports the target namespaced (SwiftCollections::BasicContainers); building from
# source (FetchContent) defines the plain `BasicContainers`. Expose one name for downstream targets.
if(TARGET SwiftCollections::BasicContainers)
  set(_SM_BASIC_CONTAINERS SwiftCollections::BasicContainers)
else()
  set(_SM_BASIC_CONTAINERS BasicContainers)
endif()

add_subdirectory(Sources)
add_subdirectory(cmake/modules)
