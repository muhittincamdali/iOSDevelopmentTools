// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        .library(
            name: "iOSDevelopmentTools",
            targets: ["iOSDevelopmentTools"]),
        .library(
            name: "NetworkTools",
            targets: ["NetworkTools"]),
        .library(
            name: "StorageTools",
            targets: ["StorageTools"]),
        .library(
            name: "AnalyticsTools",
            targets: ["AnalyticsTools"]),
        .library(
            name: "DebugTools",
            targets: ["DebugTools"]),
        .library(
            name: "UtilityTools",
            targets: ["UtilityTools"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.1"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.18.0"),
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.54.0")
    ],
    targets: [
        .target(
            name: "iOSDevelopmentTools",
            dependencies: [
                "NetworkTools",
                "StorageTools",
                "AnalyticsTools",
                "DebugTools",
                "UtilityTools"
            ]),
        .target(
            name: "NetworkTools",
            dependencies: ["Alamofire"]),
        .target(
            name: "StorageTools",
            dependencies: []),
        .target(
            name: "AnalyticsTools",
            dependencies: [
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk")
            ]),
        .target(
            name: "DebugTools",
            dependencies: []),
        .target(
            name: "UtilityTools",
            dependencies: []),
        .testTarget(
            name: "iOSDevelopmentToolsTests",
            dependencies: ["iOSDevelopmentTools"])
    ]
) 