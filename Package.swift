// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PeekCam",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PeekCam", targets: ["PeekCam"]),
        // Used by KTools (one menu bar icon for all tools) through `PeekCamService`.
        .library(name: "PeekCamKit", targets: ["PeekCamKit"]),
    ],
    targets: [
        // Pure logic: settings, size presets, camera choice. No AppKit or AVFoundation.
        .target(name: "PeekCamCore"),
        // AppKit + AVFoundation: camera session, preview popover, hot key, and the
        // `PeekCamService` facade.
        .target(
            name: "PeekCamKit",
            dependencies: ["PeekCamCore"]
        ),
        // Thin standalone app: a status item around PeekCamService.
        .executableTarget(
            name: "PeekCam",
            dependencies: ["PeekCamKit"]
        ),
        .testTarget(
            name: "PeekCamCoreTests",
            dependencies: ["PeekCamCore"]
        ),
    ]
)
