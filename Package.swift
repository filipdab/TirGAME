// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "TirGame3D",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "TirGame3D",
            path: "Sources/TirGame3D"
        )
    ]
)
