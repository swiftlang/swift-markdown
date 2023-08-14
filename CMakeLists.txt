#[[
This source file is part of the Swift System open source project

Copyright (c) 2024 Apple Inc. and the Swift System project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

cmake_minimum_required(VERSION 3.19.0)

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

find_package(ArgumentParser CONFIG)
if(NOT ArgumentParser_FOUND)
  FetchContent_Declare(ArgumentParser
    GIT_REPOSITORY https://github.com/apple/swift-argument-parser
    GIT_TAG 1.2.3)
  list(APPEND _SM_VENDOR_DEPENDENCIES ArgumentParser)
endif()

find_package(cmark-gfm CONFIG)
if(NOT cmark-gfm_FOUND)
  FetchContent_Declare(cmark-gfm
    GIT_REPOSITORY https://github.com/apple/swift-cmark
    GIT_TAG gfm)
  list(APPEND _SM_VENDOR_DEPENDENCIES cmark-gfm)
endif()

if(_SM_VENDOR_DEPENDENCIES)
  FetchContent_MakeAvailable(${_SM_VENDOR_DEPENDENCIES})
endif()

add_subdirectory(Sources)
add_subdirectory(cmake/modules)
