// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iOSDevelopmentTools",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(name: "iOSDevelopmentTools", targets: ["iOSDevelopmentTools"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "iOSDevelopmentTools",
            dependencies: [],
            path: "Sources/iOSDevelopmentTools",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .define("SWIFT_PACKAGE")
            ]
        ),
        .testTarget(
            name: "iOSDevelopmentToolsTests",
            dependencies: ["iOSDevelopmentTools"],
            path: "Tests"
        )
    ]
)
