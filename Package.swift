// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "nova-launcher",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "NovaLauncher",
            targets: ["NovaLauncher"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NovaLauncher",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "NovaLauncherTests",
            dependencies: ["NovaLauncher"]
        )
    ]
)
