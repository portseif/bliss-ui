// swift-tools-version: 6.2
import PackageDescription

/// Matches the settings the components were built and tuned under: views run on
/// the main actor by default, with approachable concurrency.
let blissSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5),
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "BlissUI",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "BlissUI", targets: ["BlissUI"]),
    ],
    targets: [
        .target(
            name: "BlissUI",
            // Localizable.xcstrings: the library's own strings, looked up in
            // `Bundle.module` so they're translated without the app's catalog.
            resources: [.process("Resources")],
            swiftSettings: blissSwiftSettings
        ),
        // A demo app of every component, built only on the public API:
        // `swift run BlissCatalog`.
        .executableTarget(
            name: "BlissCatalog",
            dependencies: ["BlissUI"],
            path: "Examples/BlissCatalog",
            swiftSettings: blissSwiftSettings
        ),
        .testTarget(
            name: "BlissUITests",
            dependencies: ["BlissUI"],
            swiftSettings: blissSwiftSettings
        ),
        // Imports BlissUI WITHOUT @testable, so it only compiles against the
        // public API — a component that isn't reachable from an app fails here.
        .testTarget(
            name: "BlissUIPublicAPITests",
            dependencies: ["BlissUI"],
            swiftSettings: blissSwiftSettings
        ),
    ]
)
