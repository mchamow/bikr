// swift-tools-version: 6.2
import PackageDescription

// Platform-independent logic for Bikr: track model, stats, GPX, storage and
// track following. Kept free of UIKit/CoreLocation so it tests with `swift test`.
let package = Package(
    name: "BikrCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "BikrCore", targets: ["BikrCore"]),
    ],
    targets: [
        .target(name: "BikrCore"),
        .testTarget(name: "BikrCoreTests", dependencies: ["BikrCore"]),
    ]
)
