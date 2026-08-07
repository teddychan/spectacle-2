import Foundation
import DragonKit

enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            // Single source of truth: the bundle's marketing version (no "v", no build number),
            // so What's New always matches the shipped release without a second edit.
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0",
            date: "2026-08-07",
            summary: L("app.whatsNew.summary"),
            // 2.4.1 is a single-fix patch: the About panel's version string was built by hand
            // here instead of by `DragonAbout.versionString()`, so it dropped the `v` prefix and
            // the UTC build time. One entry, because that is the whole release.
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                ]),
            ]
        )
    }
}
