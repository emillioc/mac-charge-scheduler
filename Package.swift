// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "chargectl",
    targets: [
        .systemLibrary(
            name: "CSMC"
        ),
        .executableTarget(
            name: "chargectl",
            dependencies: ["CSMC"]
        )
    ]
)
