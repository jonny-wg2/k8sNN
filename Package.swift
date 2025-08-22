// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "K8sNN",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "K8sNN", targets: ["K8sNN"])
    ],
    targets: [
        .executableTarget(
            name: "K8sNN",
            path: "Sources"
        )
    ]
)
