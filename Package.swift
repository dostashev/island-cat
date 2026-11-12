// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IslandCat",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "IslandCatCore"),
        .executableTarget(name: "IslandCat", dependencies: ["IslandCatCore"]),
        .testTarget(name: "IslandCatCoreTests", dependencies: ["IslandCatCore"]),
    ]
)
