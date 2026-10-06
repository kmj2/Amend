// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Amend",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "DiffCore"),
        .executableTarget(
            name: "Amend",
            dependencies: ["DiffCore"]
        ),
        .testTarget(
            name: "DiffCoreTests",
            dependencies: ["DiffCore"]
        ),
    ]
)
