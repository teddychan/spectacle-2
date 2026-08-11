import Foundation
import DragonKit

enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            // `version` is omitted deliberately: it defaults to the bundle's
            // `CFBundleShortVersionString` and the kit adds the `v`, so What's New tracks the
            // shipped release without a second edit. Pass one only to pin notes to an older release.
            date: "2026-08-11",
            summary: L("app.whatsNew.summary"),
            // 2.5.5 claims one fix: the bundle had no `NSHumanReadableCopyright`, so Finder's Get
            // Info panel showed no copyright line for Spectacle 2 at all. It now carries
            // `© 2026 Teddy Chan` — byte-for-byte the string About's copyright row renders.
            //
            // Found by auditing the field across all five Dragon apps, where it was in four
            // different states: a tagline in clipmenu-2, two holders in ice-2, and absent in this
            // app, yahoo-keykey-2 and the sample app. The key is an optional Apple one that no
            // licence names, so it is presentation, and the rule for presentation is the one About
            // already follows: a single holder, the app's own. `LICENSE` is where the MIT grant
            // lives, and it still carries Eric Czarny's notice unchanged.
            //
            // No `.changed` section this time. 2.5.4 had one because the DragonKit bump moved
            // About's "Built with" row; the pin does not move here, so claiming anything beside the
            // fix would be inventing a second change. `app.whatsNew.changed1` is removed from the
            // seven .strings files rather than left holding 2.5.4's sentence.
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                ]),
            ]
        )
    }
}
