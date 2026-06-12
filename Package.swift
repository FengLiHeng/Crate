// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Crate",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Crate",
            path: "src",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
