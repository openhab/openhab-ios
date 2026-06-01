// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonUI",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v14)],

    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CommonUI",
            targets: ["CommonUI"]
        )
    ],
    dependencies: [
        .package(path: "../OpenHABCore"),
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", from: "7.0.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.6.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CommonUI",
            dependencies: [
                "OpenHABCore",
                .product(name: "SFSafeSymbols", package: "SFSafeSymbols"),
                .product(name: "Kingfisher", package: "Kingfisher")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                //                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("StrictConcurrency"),
                .unsafeFlags([
                    "-Xfrontend", "-enable-actor-data-race-checks",
                    "-Xfrontend", "-strict-concurrency=complete"
                ])
            ]
        ),
        .testTarget(
            name: "CommonUITests",
            dependencies: [
                .product(name: "Numerics", package: "swift-numerics"),
                "CommonUI"
            ]
        )
    ]
)
