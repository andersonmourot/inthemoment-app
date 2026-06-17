// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InTheMomentCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "InTheMomentCore",
            targets: ["InTheMomentCore"]
        )
    ],
    targets: [
        .target(
            name: "InTheMomentCore"
        ),
        .testTarget(
            name: "InTheMomentCoreTests",
            dependencies: ["InTheMomentCore"]
        )
    ]
)
