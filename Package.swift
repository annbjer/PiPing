// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SettleBell",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "SettleBellCore", targets: ["SettleBellCore"]),
        .library(name: "SettleBellCloudKit", targets: ["SettleBellCloudKit"]),
        .executable(name: "SettleBellMac", targets: ["SettleBellMac"]),
        .executable(name: "SettleBellSignal", targets: ["SettleBellSignal"]),
        .executable(name: "SettleBellIOS", targets: ["SettleBellIOS"]),
    ],
    targets: [
        .target(name: "SettleBellCore"),
        .target(
            name: "SettleBellCloudKit",
            dependencies: ["SettleBellCore"]
        ),
        .executableTarget(
            name: "SettleBellMac",
            dependencies: ["SettleBellCore", "SettleBellCloudKit"]
        ),
        .executableTarget(
            name: "SettleBellSignal",
            dependencies: ["SettleBellCore"]
        ),
        .executableTarget(
            name: "SettleBellIOS",
            dependencies: ["SettleBellCore", "SettleBellCloudKit"]
        ),
        .testTarget(
            name: "SettleBellCoreTests",
            dependencies: ["SettleBellCore"]
        ),
        .testTarget(
            name: "SettleBellCloudKitTests",
            dependencies: ["SettleBellCore", "SettleBellCloudKit"]
        ),
        .testTarget(
            name: "SettleBellMacTests",
            dependencies: ["SettleBellCore", "SettleBellMac"]
        ),
    ]
)
