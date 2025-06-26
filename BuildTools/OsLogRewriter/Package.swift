// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "OsLogRewriter",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
    ],
    targets: [
        .executableTarget(
            name: "OsLogRewriter",
            dependencies: [
                "OsLogRewriterLib",
            ]
        ),
        .target(
            name: "OsLogRewriterLib",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "OsLogRewriterTests",
            dependencies: [
                "OsLogRewriterLib",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        )
    ]
)
