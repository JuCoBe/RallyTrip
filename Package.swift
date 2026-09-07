// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RallyCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "RallyCore", targets: ["RallyCore"])],
    targets: [
        .target(name: "RallyCore"),
        .testTarget(name: "RallyCoreTests", dependencies: ["RallyCore"])
    ]
)
