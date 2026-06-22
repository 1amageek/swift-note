// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-note",
    products: [
        .executable(name: "snote", targets: ["SwiftNoteCLI"]),
        .library(name: "SwiftNoteCore", targets: ["SwiftNoteCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", branch: "release/6.4.x"),
    ],
    targets: [
        .target(
            name: "SwiftNoteCore",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .executableTarget(
            name: "SwiftNoteCLI",
            dependencies: ["SwiftNoteCore"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "SwiftNoteCoreTests",
            dependencies: ["SwiftNoteCore"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ],
    swiftLanguageModes: [.v6]
)
