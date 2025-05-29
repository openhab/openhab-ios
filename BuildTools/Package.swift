// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v10_13)],
    dependencies: [
        .package(url: "https://github.com/weakfl/SwiftFormatPlugin", exact: "0.56.1"),
        .package(url: "https://github.com/weakfl/SwiftLintPlugin.git", exact: "0.59.1")
    ],
    targets: [
        .target(
            name: "BuildTools",
            path: ""
        )
    ]
)
