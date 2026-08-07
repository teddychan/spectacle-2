import Foundation
import DragonKit

enum AboutConfig {
    /// The single source of truth for the app version: the bundle's Info.plist, formatted by
    /// DragonKit as `v2.4.1 (760) · 2026-Aug-07 13:34:56 UTC`. Never hardcode it — bump
    /// `CFBundleShortVersionString` / `CFBundleVersion` and About, backups, and update checks
    /// all read the same value.
    ///
    /// This delegates rather than re-deriving the format. It used to build the string by hand,
    /// which silently dropped the `v` prefix and the UTC build time every other Dragon app
    /// shows: `DragonAbout` landed in kit v1.3.0 nineteen minutes after this app was scaffolded
    /// against `from: "1.2.1"`, so at the time there was nothing to call, and the stopgap was
    /// never revisited across five kit bumps.
    static var versionString: String {
        DragonAbout.versionString()
    }

    @MainActor
    static var content: AboutContent {
        AboutContent(
            appName: AppIdentity.displayName,
            versionString: versionString,
            copyright: "© 2026 Teddy Chan",
            links: [
                AboutLink(
                    title: L("app.about.website"),
                    detail: "dragonapp.com",
                    systemImage: "globe",
                    url: URL(string: "https://www.dragonapp.com")!
                ),
                AboutLink(
                    title: L("app.about.source"),
                    detail: "teddychan/spectacle-2",
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    url: URL(string: "https://github.com/teddychan/spectacle-2")!
                ),
                // Credit + link to the original Spectacle, which this app reimplements.
                AboutLink(
                    title: L("app.about.original"),
                    detail: "eczarny/spectacle",
                    systemImage: "eyeglasses",
                    url: URL(string: "https://github.com/eczarny/spectacle")!
                ),
            ],
            credits: [
                (label: L("app.about.basedOn"), value: "Spectacle by Eric Czarny"),
                (label: L("app.about.builtWith"), value: "DragonKit"),
                (label: L("app.about.license"), value: "MIT"),
            ]
        )
    }
}
