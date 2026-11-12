// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "logic-pro-tools",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "logic-mcu", path: "Sources/logic-mcu"),
        .executableTarget(name: "logic-ax", path: "Sources/logic-ax"),
    ]
)
