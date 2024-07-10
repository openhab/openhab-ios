// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenHABCore",
    platforms: [.iOS(.v12), .watchOS(.v6)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "OpenHABCore",
            targets: ["OpenHABCore"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "Alamofire", url: "https://github.com/Alamofire/Alamofire.git", from: "5.0.0"),
        .package(name: "Kingfisher", url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "OpenHABCore",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire", condition: .when(platforms: [.iOS, .watchOS])),
                .product(name: "Kingfisher", package: "Kingfisher", condition: .when(platforms: [.iOS, .watchOS]))
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
