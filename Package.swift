// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TextDiff",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "DiffCore"),
        .executableTarget(
            name: "TextDiff",
            dependencies: ["DiffCore"]
        ),
        .testTarget(
            name: "DiffCoreTests",
            dependencies: ["DiffCore"]
        ),
    ]
)
