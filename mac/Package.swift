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
            path: "Sources/FlashNote"
        )
        // 注：测试放在 Xcode 工程里更稳（SwiftPM 在 CLI toolchain 下偶发 XCTest 找不到）
    ]
)
