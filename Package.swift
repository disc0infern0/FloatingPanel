// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FloatingPanel",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FloatingPanel",
            targets: ["FloatingPanel"]
        ),
        .executable(
            name: "FloatingPanelDemo",
            targets: ["FloatingPanelDemo"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FloatingPanel",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .testTarget(
            name: "FloatingPanelTests",
            dependencies: ["FloatingPanel"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .executableTarget(
            name: "FloatingPanelDemo",
            dependencies: ["FloatingPanel"],
            path: "Sources/FloatingPanelDemo",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/FloatingPanelDemo/Info.plist"
                ])
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
