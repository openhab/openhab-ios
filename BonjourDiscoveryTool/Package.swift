// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BonjourDiscoveryTool",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "bonjour-discovery", targets: ["BonjourDiscoveryTool"])
    ],
    targets: [
        .executableTarget(
            name: "BonjourDiscoveryTool",
            path: "Sources"
        )
    ]
)
