// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pasted",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Pasted",
            path: "Pasted",
            exclude: ["Info.plist", "Pasted.entitlements"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PastedTests",
            dependencies: ["Pasted"],
            path: "PastedTests"
        )
    ]
)
