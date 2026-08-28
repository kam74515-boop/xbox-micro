// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "XboxMicro",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "XboxMicroCore", targets: ["XboxMicroCore"]),
        .executable(name: "XboxMicro", targets: ["XboxMicroApp"]),
    ],
    targets: [
        .target(name: "XboxMicroCore"),
        .executableTarget(
            name: "XboxMicroApp",
            dependencies: ["XboxMicroCore"]
        ),
        .testTarget(
            name: "XboxMicroCoreTests",
            dependencies: ["XboxMicroCore"]
        ),
    ]
)
