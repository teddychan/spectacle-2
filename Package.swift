// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Spectacle2",
    defaultLocalization: "en",
    platforms: [.macOS("26")],
    dependencies: [
        // Direct-download app → link BOTH DragonKit and DragonKitUpdates (Sparkle).
        //
        // `from:`, not `exact:` — the Dragon apps state the kit pin one way, and this app was the
        // last one still on `exact:`. clipmenu-2 writes `from: "3.2.0"` literally; ice-2's
        // .pbxproj spells the same range as upToNextMajorVersion / minimumVersion 3.2.0.
        //
        // The tradeoff lands harder here than on either of those: Package.resolved is gitignored
        // in this repo, while they commit theirs and are therefore locked to a resolved revision.
        // Every CI build here resolves from scratch, so a 3.x kit tag published before the next
        // release floats into that release with nobody having run the app against it. That is the
        // accepted price of the unified pin form, not an oversight — which is why a kit bump still
        // wants a deliberate build-and-run check, on the version that actually resolved, before a
        // release tag goes out.
        .package(url: "https://github.com/teddychan/dragon-kit", from: "3.3.0"),
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
        .testTarget(name: "Spectacle2Tests", dependencies: ["Spectacle2"]),
    ]
)
