// swift-tools-version:6.2
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageDescription
import class Foundation.ProcessInfo

// The CommonMark parser uses `~Copyable`/`~Escapable`, lifetime-dependent API requires these experimental features. Consuming it (the `Markdown` target) does not.
let commonMarkSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .enableExperimentalFeature("LifetimeDependence"),
    .enableExperimentalFeature("Lifetimes"),
    .swiftLanguageMode(.v6),
]

let package = Package(
    name: "swift-markdown",
    products: [
        .library(
            name: "Markdown",
            targets: ["Markdown"]),
        .library(
            name: "CommonMark",
            targets: ["CommonMark"]),
    ],
    targets: [
        .target(
            name: "Markdown",
            dependencies: [
                "CAtomic",
                "CommonMark",
            ],
            exclude: [
                "CMakeLists.txt"
            ]
        ),
        .target(
            name: "CommonMark",
            dependencies: [
                .product(name: "BasicContainers", package: "swift-collections"),
            ],
            exclude: [
                "CMakeLists.txt"
            ],
            swiftSettings: commonMarkSwiftSettings + [
                // Built with library evolution so a separate package does not see the BasicContainers dependency.
                .unsafeFlags(["-enable-library-evolution"]),
            ]
        ),
        .testTarget(
            name: "MarkdownTests",
            dependencies: ["Markdown"],
            resources: [.process("Visitors/Everything.md")]),
        .testTarget(
            name: "CommonMarkTests",
            dependencies: ["CommonMark"],
            resources: [
                .copy("spec.txt"),
            ],
            swiftSettings: commonMarkSwiftSettings
        ),
        .target(name: "CAtomic"),
    ],
    swiftLanguageModes: [.v5]
)

// If the `SWIFTCI_USE_LOCAL_DEPS` environment variable is set,
// we're building in the Swift.org CI system alongside other projects in the Swift toolchain and
// we can depend on local versions of our dependencies instead of fetching them remotely.
if ProcessInfo.processInfo.environment["SWIFTCI_USE_LOCAL_DEPS"] == nil {
    // Building standalone, so fetch all dependencies remotely.
    package.dependencies += [
        .package(url: "https://github.com/apple/swift-collections", from: "1.6.0"),
    ]

    // SwiftPM command plugins are only supported by Swift version 5.6 and later.
    #if swift(>=5.6)
    package.dependencies += [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.1.0"),
    ]
    #endif
} else {
    // Building in the Swift.org CI system, so rely on local checkouts of our dependencies as siblings.
    package.dependencies += [
        .package(path: "../swift-collections"),
    ]
}
