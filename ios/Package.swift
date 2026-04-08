// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BIShareProtocol",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        // .tvOS(.v17) — future
    ],
    products: [
        .library(
            name: "BIShareProtocol",
            targets: ["BIShareProtocol"]
        )
    ],
    targets: [
        .target(
            name: "BIShareProtocol",
            dependencies: [],
            path: "Sources/BIShareProtocol"
        ),
        .testTarget(
            name: "BIShareProtocolTests",
            dependencies: ["BIShareProtocol"],
            path: "Tests/BIShareProtocolTests"
        )
    ]
)
