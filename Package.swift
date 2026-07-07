// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Spectacle2",
    defaultLocalization: "en",
    platforms: [.macOS("26")],
    dependencies: [
        // Direct-download app → link BOTH DragonKit and DragonKitUpdates (Sparkle).
        .package(url: "https://github.com/teddychan/dragon-kit", from: "1.4.0"),
    ],
    targets: [
        .target(name: "SpectacleCore"),
        .executableTarget(
            name: "Spectacle2",
            dependencies: [
                "SpectacleCore",
                .product(name: "DragonKit", package: "dragon-kit"),
                .product(name: "DragonKitUpdates", package: "dragon-kit"),
            ],
            // Bundle the app's own localizations (Resources/<lang>.lproj) into
            // Spectacle2_Spectacle2.bundle so both run.sh and the release CI ship them via
            // the standard SwiftPM resource-bundle copy. Resolved at runtime through
            // LocalizationManager.appStringsBundle = AppResources.stringsBundle (in AppDelegate).
            resources: [.process("Resources")],
            // Embed the rpath the release CI relies on to locate the bundled
            // Sparkle.framework at Contents/Frameworks/. Without this the packaged .app only
            // carries the default @loader_path rpath, so dyld looks for Sparkle in
            // Contents/MacOS/ and the app crashes on launch (Library not loaded: Sparkle).
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path/../Frameworks"])
            ]
        ),
        .testTarget(name: "SpectacleCoreTests", dependencies: ["SpectacleCore"]),
    ]
)
