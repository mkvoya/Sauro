// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sauro",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Sauro", targets: ["SauroApp"])
    ],
    targets: [
        .executableTarget(
            name: "SauroApp",
            path: "Sources/SauroApp"
        )
    ]
)
