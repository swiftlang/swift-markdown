// swift-tools-version:5.3
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageDescription
import class Foundation.ProcessInfo

let package = Package(
    name: "swift-markdown",
    products: [
        .library(
            name: "Markdown",
            targets: ["Markdown"]),
        .executable(
            name: "markdown-tool",
            targets: ["markdown-tool"]),
    ],
    targets: [
        .target(
            name: "Markdown",
            dependencies: [
                "CAtomic",
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ]),
        .target(
            name: "markdown-tool",
            dependencies: [
                "Markdown",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
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
        .package(url: "https://github.com/apple/swift-cmark.git", .branch("gfm")),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.4.4")),
    ]
} else {
    // Building in the Swift.org CI system, so rely on local versions of dependencies.
    package.dependencies += [
        .package(path: "../swift-cmark-gfm"),
        .package(path: "../swift-argument-parser"),
    ]
}
