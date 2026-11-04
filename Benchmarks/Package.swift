// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-markdown-benchmarks",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0"),
        .tvOS("26.0"),
        .watchOS("26.0"),
        .visionOS("26.0"),
    ],
    dependencies: [
        .package(name: "swift-markdown", path: ".."),
        .package(url: "https://github.com/ordo-one/benchmark.git", from: "1.11.1"),
        .package(url: "https://github.com/swiftlang/swift-cmark.git", branch: "gfm"),
    ],
    targets: [
        .executableTarget(
            name: "ComparisonBenchmarks",
            dependencies: [
                .product(name: "CommonMark", package: "swift-markdown"),
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ],
            path: "Benchmarks/Comparison",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
            ],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
