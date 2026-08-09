// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlashNote",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlashNote", targets: ["FlashNote"])
    ],
    targets: [
        .executableTarget(
            name: "FlashNote",
            path: "Sources/FlashNote",
            resources: [
                .copy("Resources/icon-1024.png"),
                .copy("Resources/web")
            ]
        ),
        .testTarget(
            name: "FlashNoteTests",
            dependencies: ["FlashNote"],
            path: "Tests/FlashNoteTests"
        )
    ]
)
