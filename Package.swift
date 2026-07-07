// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sleepless",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic (parsing, decisions, formatting) — unit-tested, no system dependencies.
        .target(
            name: "SleeplessCore",
            path: "Sources/SleeplessCore"
        ),
        .executableTarget(
            name: "Sleepless",
            dependencies: ["SleeplessCore"],
            path: "Sources/Sleepless",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
            ]
        ),
        .testTarget(
            name: "SleeplessCoreTests",
            dependencies: ["SleeplessCore"],
            path: "Tests/SleeplessCoreTests"
        ),
    ]
)
