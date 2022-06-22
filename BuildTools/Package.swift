// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v10_12)],
    dependencies: [
        // Define any tools you want available from your build phases
        // Here's an example with SwiftFormat
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.46.2"),
        .package(url: "https://github.com/realm/SwiftLint", from: "0.40.1")
    ],
    targets: [.target(name: "BuildTools", path: "")]
)
