// swift-tools-version: 6.0
// Pacote que expõe o núcleo em Rust para o Swift.
// O xcframework e o yggi_core.swift são gerados por scripts/build-core.sh (não versionados).
import PackageDescription

let package = Package(
    name: "YggiCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "YggiCore", targets: ["YggiCore"]),
    ],
    targets: [
        .binaryTarget(name: "yggi_coreFFI", path: "YggiCoreFFI.xcframework"),
        .target(name: "YggiCore", dependencies: ["yggi_coreFFI"]),
    ]
)
