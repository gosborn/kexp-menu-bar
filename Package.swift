// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KEXPMenuBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "KEXPMenuBar", path: "Sources/KEXPMenuBar")
    ]
)
