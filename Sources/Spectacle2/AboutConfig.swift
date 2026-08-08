import Foundation
import DragonKit

/// Spectacle 2's content for DragonKit's shared About pane. Layout is owned by DragonKit
/// (`AboutPane`); only the text and links here are the app's. The version is single-sourced
/// from Info.plist via `DragonAbout.versionString()` — never hardcode or reformat it, so every
/// Dragon app renders the same shape: `v<short> (<build>) · <UTC build time>`.
enum AboutConfig {
    @MainActor
    static var content: AboutContent {
        AboutContent(
            appName: AppIdentity.displayName,
            versionString: DragonAbout.versionString(),
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
