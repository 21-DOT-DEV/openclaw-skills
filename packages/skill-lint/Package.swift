// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "skill-lint",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "skill-lint",
            targets: ["skill-lint"]
        ),
        .library(
            name: "SkillLintLib",
            targets: ["SkillLintLib"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", exact: "6.1.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.6.2"),
    ],
    targets: [
        .target(
            name: "SkillLintLib",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .executableTarget(
            name: "skill-lint",
            dependencies: [
                "SkillLintLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "SkillLintTests",
            dependencies: ["SkillLintLib"]
        ),
    ]
)
