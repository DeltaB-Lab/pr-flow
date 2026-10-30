// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PRFlow",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "PRFlow")
    ]
)
