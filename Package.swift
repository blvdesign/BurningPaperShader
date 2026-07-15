// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "BurningPaperShader",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .library(
            name: "BurningPaper",
            targets: ["BurningPaper"]
        )
    ],
    targets: [
        .target(
            name: "BurningPaperShaderTypes",
            publicHeadersPath: "include"
        ),
        .target(
            name: "BurningPaper",
            dependencies: ["BurningPaperShaderTypes"]
        ),
        .testTarget(
            name: "BurningPaperTests",
            dependencies: ["BurningPaper", "BurningPaperShaderTypes"]
        )
    ]
)
