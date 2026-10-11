// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kkokkomu", platforms: [.macOS("26.0")],
    products: [
        .executable(name: "Kkokkomu", targets: ["KkokkomuApp"]),
        .executable(name: "KkokkomuQA", targets: ["KkokkomuQA"]),
    ],
    targets: [
        .target(name: "KkokkomuCore"),
        .executableTarget(name: "KkokkomuApp", dependencies: ["KkokkomuCore"]),
        .executableTarget(name: "KkokkomuQA", dependencies: ["KkokkomuCore"]),
        .testTarget(name: "KkokkomuCoreTests", dependencies: ["KkokkomuCore"]),
        .testTarget(name: "KkokkomuAppTests", dependencies: ["KkokkomuApp"]),
    ], swiftLanguageModes: [.v6])
