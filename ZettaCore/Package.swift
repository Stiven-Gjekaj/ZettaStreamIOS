// swift-tools-version: 6.0
import PackageDescription

// The parts of the app that do not need a screen. They build and test on a Mac
// with `swift test`, so a test does not need a simulator.
let package = Package(
    name: "ZettaCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "ZettaCore", targets: ["ZettaCore"])],
    targets: [
        .target(name: "ZettaCore"),
        .testTarget(name: "ZettaCoreTests", dependencies: ["ZettaCore"]),
    ]
)
