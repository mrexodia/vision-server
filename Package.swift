// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "apple-ocr-server",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "vision-server", targets: ["VisionServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.62.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "VisionServer",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "vision-server"
        )
    ]
)
