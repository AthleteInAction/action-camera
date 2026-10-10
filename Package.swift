// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "action-camera",
    platforms: [
        .iOS(.v18),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "ActionCamera",
            targets: ["ActionCamera"]
        ),
    ],
    targets: [
        .target(
            name: "ActionCamera"
        ),
        .testTarget(
            name: "ActionCameraTests",
            dependencies: ["ActionCamera"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
