// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenHABCore",
    platforms: [.iOS(.v16), .watchOS(.v8)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "OpenHABCore",
            targets: ["OpenHABCore"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.0.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.1.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "OpenHABCore",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire", condition: .when(platforms: [.iOS, .watchOS])),
                .product(name: "Kingfisher", package: "Kingfisher", condition: .when(platforms: [.iOS, .watchOS])),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .testTarget(
            name: "OpenHABCoreTests",
            dependencies: ["OpenHABCore"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
