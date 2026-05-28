// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v10_13)],
    dependencies: [
        .package(url: "https://github.com/weakfl/SwiftFormatPlugin", exact: "0.61.1"),
        .package(url: "https://github.com/weakfl/SwiftLintPlugin.git", exact: "0.63.3")
    ],
    targets: [
        .target(
            name: "BuildTools",
            path: ""
        )
    ]
)
