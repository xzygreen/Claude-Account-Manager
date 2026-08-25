// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ClaudeAccountManager",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ClaudeAccountManager", targets: ["ClaudeAccountManager"])
    ],
    targets: [
        .executableTarget(
            name: "ClaudeAccountManager",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Security"),
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "ClaudeAccountManagerTests",
            dependencies: ["ClaudeAccountManager"]
        )
    ]
)
