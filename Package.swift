// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "BurningPaper",
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
            // TN3133: keep Shaders.metal as source. Xcode's CompileMetalFile/MetalLink
            // stages Bundle.module/default.metallib; declaring it as .copy would be incorrect.
            dependencies: ["BurningPaperShaderTypes"]
        ),
        .testTarget(
            name: "BurningPaperTests",
            dependencies: ["BurningPaper", "BurningPaperShaderTypes"]
        )
    ]
)
