// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "OpenWebUIiOS",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "OpenWebUIiOS",
            targets: ["OpenWebUIiOS"]),
    ],
    dependencies: [
        // Dependencies for markdown rendering
        .package(url: "https://github.com/johnxnguyen/Down", from: "0.11.0"),
        // Dependencies for syntax highlighting
        .package(url: "https://github.com/raspu/Highlightr", from: "2.1.2"),
        // Dependencies for WebSockets
        .package(url: "https://github.com/daltoniam/Starscream", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "OpenWebUIiOS",
            dependencies: [
                "Down",
                "Highlightr",
                "Starscream"
            ],
            path: "Sources"),
        .testTarget(
            name: "OpenWebUIiOSTests",
            dependencies: ["OpenWebUIiOS"],
            path: "Tests"),
    ]
)