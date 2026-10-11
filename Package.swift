// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tail", platforms: [.macOS("26.0")],
    products: [
        .executable(name: "Tail", targets: ["TailApp"]),
        .executable(name: "TailQA", targets: ["TailQA"]),
    ],
    targets: [
        .target(name: "TailCore"),
        .executableTarget(name: "TailApp", dependencies: ["TailCore"]),
        .executableTarget(name: "TailQA", dependencies: ["TailCore"]),
        .testTarget(name: "TailCoreTests", dependencies: ["TailCore"]),
    ], swiftLanguageModes: [.v6])
