// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sleepless",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Sleepless",
            path: "Sources/Sleepless",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
            ]
        )
    ]
)
