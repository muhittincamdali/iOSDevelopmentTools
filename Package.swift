// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "iOSDevelopmentTools",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "iOSDevelopmentTools", targets: ["iOSDevelopmentTools"])
    ],
    targets: [
        .target(name: "iOSDevelopmentTools"),
        .testTarget(
            name: "iOSDevelopmentToolsTests",
            dependencies: ["iOSDevelopmentTools"]
        )
    ]
)
