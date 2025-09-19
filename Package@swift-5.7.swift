// swift-tools-version:5.7
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageDescription
import class Foundation.ProcessInfo

let cmarkPackageName = ProcessInfo.processInfo.environment["SWIFTCI_USE_LOCAL_DEPS"] == nil ? "swift-cmark" : "cmark"

let package = Package(
    name: "swift-markdown",
    products: [
        .library(
            name: "Markdown",
            targets: ["Markdown"]),
    ],
    targets: [
        .target(
            name: "Markdown",
            dependencies: [
                "CAtomic",
                .product(name: "cmark-gfm", package: cmarkPackageName),
                .product(name: "cmark-gfm-extensions", package: cmarkPackageName),
            ],
            exclude: [
                "CMakeLists.txt"
            ]
        ),
        .testTarget(
            name: "MarkdownTests",
            dependencies: ["Markdown"],
            resources: [.process("Visitors/Everything.md")]),
        .target(name: "CAtomic"),
    ]
)

// If the `SWIFTCI_USE_LOCAL_DEPS` environment variable is set,
// we're building in the Swift.org CI system alongside other projects in the Swift toolchain and
// we can depend on local versions of our dependencies instead of fetching them remotely.
if ProcessInfo.processInfo.environment["SWIFTCI_USE_LOCAL_DEPS"] == nil {
    // Building standalone, so fetch all dependencies remotely.
    package.dependencies += [
        .package(url: "https://github.com/swiftlang/swift-cmark.git", branch: "gfm"),
    ]
    
    // SwiftPM command plugins are only supported by Swift version 5.6 and later.
    #if swift(>=5.6)
    package.dependencies += [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.1.0"),
    ]
    #endif
} else {
    // Building in the Swift.org CI system, so rely on local versions of dependencies.
    package.dependencies += [
        .package(path: "../cmark"),
    ]
}
