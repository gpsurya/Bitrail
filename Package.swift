// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Bitrail",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Bitrail", targets: ["Bitrail"])
    ],
    dependencies: [
        .package(url: "https://github.com/ejbills/mediaremote-adapter.git", branch: "master"),
        .package(url: "https://github.com/rnine/SimplyCoreAudio.git", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Bitrail",
            dependencies: [
                .product(name: "MediaRemoteAdapter", package: "mediaremote-adapter"),
                .product(name: "SimplyCoreAudio", package: "SimplyCoreAudio")
            ]
        ),
        .testTarget(
            name: "BitrailTests",
            dependencies: ["Bitrail"]
        )
    ]
)
