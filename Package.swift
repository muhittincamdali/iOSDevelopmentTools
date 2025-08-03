// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iOSDevelopmentTools",
    platforms: [
        .iOS(.v15),
        .iPadOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Main library
        .library(
            name: "iOSDevelopmentTools",
            targets: ["iOSDevelopmentTools"]
        ),
        
        // Individual tool libraries
        .library(
            name: "NetworkTools",
            targets: ["NetworkTools"]
        ),
        .library(
            name: "StorageTools",
            targets: ["StorageTools"]
        ),
        .library(
            name: "AnalyticsTools",
            targets: ["AnalyticsTools"]
        ),
        .library(
            name: "DebugTools",
            targets: ["DebugTools"]
        ),
        .library(
            name: "UtilityTools",
            targets: ["UtilityTools"]
        )
    ],
    dependencies: [
        // Core dependencies
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.1"),
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.54.0"),
        
        // Testing dependencies
        .package(url: "https://github.com/Quick/Quick.git", from: "7.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "12.0.0")
    ],
    targets: [
        // Main target
        .target(
            name: "iOSDevelopmentTools",
            dependencies: [
                "NetworkTools",
                "StorageTools", 
                "AnalyticsTools",
                "DebugTools",
                "UtilityTools"
            ],
            path: "Sources/iOSDevelopmentTools",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .define("RELEASE", .when(configuration: .release)),
                .unsafeFlags(["-warn-implicit-override"])
            ]
        ),
        
        // Network Tools
        .target(
            name: "NetworkTools",
            dependencies: ["Alamofire"],
            path: "Sources/NetworkTools",
            swiftSettings: [
                .define("NETWORK_DEBUG", .when(configuration: .debug))
            ]
        ),
        
        // Storage Tools
        .target(
            name: "StorageTools",
            path: "Sources/StorageTools",
            swiftSettings: [
                .define("STORAGE_DEBUG", .when(configuration: .debug))
            ]
        ),
        
        // Analytics Tools
        .target(
            name: "AnalyticsTools",
            path: "Sources/AnalyticsTools",
            swiftSettings: [
                .define("ANALYTICS_DEBUG", .when(configuration: .debug))
            ]
        ),
        
        // Debug Tools
        .target(
            name: "DebugTools",
            path: "Sources/DebugTools",
            swiftSettings: [
                .define("DEBUG_TOOLS_ENABLED", .when(configuration: .debug))
            ]
        ),
        
        // Utility Tools
        .target(
            name: "UtilityTools",
            path: "Sources/UtilityTools",
            swiftSettings: [
                .define("UTILITY_DEBUG", .when(configuration: .debug))
            ]
        ),
        
        // Tests
        .testTarget(
            name: "iOSDevelopmentToolsTests",
            dependencies: [
                "iOSDevelopmentTools",
                "Quick",
                "Nimble"
            ],
            path: "Tests/iOSDevelopmentToolsTests",
            resources: [
                .process("Resources")
            ]
        ),
        
        // Unit Tests
        .testTarget(
            name: "NetworkToolsTests",
            dependencies: ["NetworkTools", "Quick", "Nimble"],
            path: "Tests/UnitTests/NetworkTools"
        ),
        
        .testTarget(
            name: "StorageToolsTests", 
            dependencies: ["StorageTools", "Quick", "Nimble"],
            path: "Tests/UnitTests/StorageTools"
        ),
        
        .testTarget(
            name: "AnalyticsToolsTests",
            dependencies: ["AnalyticsTools", "Quick", "Nimble"],
            path: "Tests/UnitTests/AnalyticsTools"
        ),
        
        .testTarget(
            name: "DebugToolsTests",
            dependencies: ["DebugTools", "Quick", "Nimble"],
            path: "Tests/UnitTests/DebugTools"
        ),
        
        .testTarget(
            name: "UtilityToolsTests",
            dependencies: ["UtilityTools", "Quick", "Nimble"],
            path: "Tests/UnitTests/UtilityTools"
        ),
        
        // Integration Tests
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "iOSDevelopmentTools",
                "Quick",
                "Nimble"
            ],
            path: "Tests/IntegrationTests"
        ),
        
        // Performance Tests
        .testTarget(
            name: "PerformanceTests",
            dependencies: [
                "iOSDevelopmentTools",
                "Quick",
                "Nimble"
            ],
            path: "Tests/PerformanceTests"
        )
    ],
    swiftSettings: [
        .define("SWIFT_PACKAGE"),
        .define("iOS_DEVELOPMENT_TOOLS_VERSION", to: "1.0.0"),
        .define("MINIMUM_IOS_VERSION", to: "15.0"),
        .unsafeFlags(["-enable-testing"])
    ]
) 