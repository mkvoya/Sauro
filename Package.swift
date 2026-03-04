// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Sauro",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Sauro",
            path: "Sauro",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "SauroTests",
            dependencies: ["Sauro"],
            path: "SauroTests"
        )
    ]
)
