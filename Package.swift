// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Picker",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Picker",
            path: "Sources/Picker",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
