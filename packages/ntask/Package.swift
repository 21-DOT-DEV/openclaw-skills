// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "notion-task-skill",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ntask",
            targets: ["ntask"]
        ),
        .library(
            name: "NTaskLib",
            targets: ["NTaskLib"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.6.2"),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", exact: "0.2.1"),
        .package(url: "https://github.com/apple/swift-system.git", exact: "1.5.0"),
    ],
    targets: [
        .target(
            name: "NTaskLib",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SystemPackage", package: "swift-system"),
            ]
        ),
        .executableTarget(
            name: "ntask",
            dependencies: ["NTaskLib"]
        ),
        .testTarget(
            name: "ntaskTests",
            dependencies: ["NTaskLib"]
        ),
    ]
)
