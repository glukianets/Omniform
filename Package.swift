// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Omniform",
    platforms: [.iOS(.v14), .macOS(.v12)],
    products: [
        .library(
            name: "Omniform",
            targets: ["Omniform"]
        ),
        .library(
            name: "Omniform-SwiftUI",
            targets: ["Omniform-SwiftUI"]
        ),

    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Omniform",
            dependencies: []
        ),
        .target(
            name: "Omniform-SwiftUI",
            dependencies: ["Omniform"]
        ),
        .testTarget(
            name: "OmniformTests",
            dependencies: ["Omniform"]
        ),
    ]
)
