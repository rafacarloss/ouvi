// swift-tools-version:6.0
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5),
]

let package = Package(
    name: "Ouvi",
    platforms: [
        .macOS("14.4"),
    ],
    products: [
        .executable(name: "Ouvi", targets: ["Ouvi"]),
        .executable(name: "ouvi-mcp", targets: ["OuviMCP"]),
        .library(name: "OuviKit", targets: ["OuviKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.12.4"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),
    ],
    targets: [
        // Vendored sqlite-vec (v0.1.9) statically linked and registered via sqlite3_auto_extension.
        .target(
            name: "CSQLiteVec",
            cSettings: [
                .define("SQLITE_VEC_STATIC"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .target(
            name: "OuviKit",
            dependencies: [
                "CSQLiteVec",
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "Ouvi",
            dependencies: [
                "OuviKit",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "OuviMCP",
            dependencies: ["OuviKit"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "OuviKitTests",
            dependencies: ["OuviKit"],
            swiftSettings: swiftSettings
        ),
    ]
)
