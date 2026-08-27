// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PiPing",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "PiPingCore", targets: ["PiPingCore"]),
        .library(name: "PiPingCloudKit", targets: ["PiPingCloudKit"]),
        .executable(name: "PiPingMac", targets: ["PiPingMac"]),
        .executable(name: "PiPingSignal", targets: ["PiPingSignal"]),
        .executable(name: "PiPingIOS", targets: ["PiPingIOS"]),
    ],
    targets: [
        .target(name: "PiPingCore"),
        .target(
            name: "PiPingCloudKit",
            dependencies: ["PiPingCore"]
        ),
        .executableTarget(
            name: "PiPingMac",
            dependencies: ["PiPingCore", "PiPingCloudKit"]
        ),
        .executableTarget(
            name: "PiPingSignal",
            dependencies: ["PiPingCore"]
        ),
        .executableTarget(
            name: "PiPingIOS",
            dependencies: ["PiPingCore", "PiPingCloudKit"]
        ),
        .testTarget(
            name: "PiPingCoreTests",
            dependencies: ["PiPingCore"]
        ),
        .testTarget(
            name: "PiPingCloudKitTests",
            dependencies: ["PiPingCore", "PiPingCloudKit"]
        ),
    ]
)
