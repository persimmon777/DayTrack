// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DayTrackCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DayTrackCore", targets: ["DayTrackCore"])
    ],
    targets: [
        .target(name: "DayTrackCore"),
        .testTarget(name: "DayTrackCoreTests", dependencies: ["DayTrackCore"])
    ]
)
