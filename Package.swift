// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XcodeProjectBump",
    products: [
        .executable(name: "XcodeProjectBump", targets: ["XcodeProjectBump"])
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/xcodeproj.git",
                 .upToNextMajor(from: "8.13.0")),
        .package(url: "https://github.com/apple/swift-argument-parser.git",
                 .upToNextMajor(from: "1.2.3")),
    ],
    targets: [
        .target(
            name: "XcodeProjectBump",
            dependencies: [
                .product(name: "XcodeProj", package: "xcodeproj"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/"
        )
    ]
)
