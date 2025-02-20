// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v10_13)],
    dependencies: [
        .package(url: "https://github.com/weakfl/SwiftFormatPlugin", exact: "0.54.3"),
        .package(url: "https://github.com/weakfl/SwiftLintPlugin.git", exact: "0.54.0")
    ],
    targets: [
        .target(
            name: "BuildTools",
            path: ""
        )
    ]
)
