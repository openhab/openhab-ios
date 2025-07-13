// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonUI",
    platforms: [.iOS(.v16), .watchOS(.v10), .macOS(.v14)],

    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CommonUI",
            targets: ["CommonUI"]
        )
    ],
    dependencies: [
        .package(path: "../OpenHABCore"),
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CommonUI",
            dependencies: ["OpenHABCore"],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("DisableOutwardActorInference"),
                .enableUpcomingFeature("DynamicActorIsolation"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
                .enableUpcomingFeature("GlobalConcurrency"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("ImportObjcForwardDeclarations"),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                //                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("IsolatedDefaultValues"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonfrozenEnumExhaustivity"),
                .enableUpcomingFeature("RegionBasedIsolation"),
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
