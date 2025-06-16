// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "ClaudeFrameworkInstaller",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "claude-installer",
            targets: ["ClaudeFrameworkInstaller"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ClaudeFrameworkInstaller",
            path: ".",
            sources: ["main.swift"]
        )
    ]
)