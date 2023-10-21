// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v10_13)],
    dependencies: [
        .package(url: "https://github.com/weakfl/SwiftFormatPlugin", exact: "0.52.7"),
        .package(url: "https://github.com/weakfl/SwiftLintPlugin.git", exact: "0.53.0")
    ],
    targets: [
        .target(
            name: "BuildTools",
            path: ""
        )
    ]
)
