import Foundation
import DragonKit

/// Spectacle 2's content for DragonKit's shared About pane. Only values live here: every row
/// title, SF Symbol, label and ordering belongs to the kit — see `AboutContent`, which took
/// free-form `links`/`credits` arrays until five apps used them to ship five visibly different
/// panes. Adding, renaming or reordering a row is now a compile error rather than something
/// spotted in a screenshot months later.
///
/// The version and copyright are single-sourced from `DragonAbout`; never hardcode or reformat
/// either. "Built with · DragonKit vX.Y.Z" is emitted by the kit with its own version, so it
/// has no field here.
enum AboutConfig {
    @MainActor
    static var content: AboutContent {
        AboutContent(
            appName: AppIdentity.displayName,
            versionString: DragonAbout.versionString(),
            copyright: DragonAbout.copyright(years: "2026", holder: "Teddy Chan"),
            // The canonical marketing page, not the studio hub this app used to link. Its path
            // is the GitHub repo name, which `AboutContent.websiteMatchesSupportRepo` checks
            // against the support row below.
            websiteURL: URL(string: "https://www.dragonapp.com/spectacle-2/")!,
            supportURL: URL(string: "https://github.com/teddychan/spectacle-2/issues")!,
            // The hosted third-party licence notices, required as of DragonKit 4.0.0. This app
            // was one of the two that left it nil while still listing `Sparkle → MIT` below —
            // naming a bundled component whose licence text was then reachable from nowhere in
            // the app, which is the half of MIT's "included in all copies" that this page carries.
            // The trailing slash is load-bearing: it is the path GitHub Pages serves, so the row
            // links the page itself rather than a redirect to it.
            licensesURL: URL(string: "https://www.dragonapp.com/spectacle-2/licenses/")!,
            license: "MIT",
            // The original Spectacle, which this app reimplements — credited as both a link and
            // a "Based on" row, the two slots the kit provides for an upstream project. As of
            // DragonKit 4.0.0 those two slots read one value, so they cannot ship apart: the URL
            // was a separate `originalProjectURL:` parameter, and clipmenu-2 and ice-2 both
            // passed the credit while omitting the URL, shipping a "Based on" row with no link to
            // the project it named anywhere in the pane.
            originalWork: OriginalWork(
                name: "Spectacle",
                author: "Eric Czarny",
                url: URL(string: "https://github.com/eczarny/spectacle")!
            ),
            attributions: [
                // The app bundles Sparkle.framework by way of DragonKitUpdates. Name → licence,
                // never a role label: this row read "Update framework → Sparkle (MIT)" while
                // clipmenu-2's read "Sparkle → MIT", which is how the canon got settled. Not
                // localized — "Sparkle" is a proper noun and "MIT" a licence identifier; the kit
                // assembles the row around them.
                Attribution(name: "Sparkle", license: "MIT"),
            ]
        )
    }
}
