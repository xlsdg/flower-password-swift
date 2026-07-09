// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlowerPasswordCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FlowerPasswordCore", targets: ["FlowerPasswordCore"])
    ],
    targets: [
        .target(
            name: "FlowerPasswordCore",
            resources: [.copy("Resources/public_suffix_list.dat")]
        ),
        .testTarget(
            name: "FlowerPasswordCoreTests",
            dependencies: ["FlowerPasswordCore"],
            resources: [.copy("Resources/golden_vectors.json")]
        ),
    ]
)
