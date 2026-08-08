import Foundation
import DragonKit

enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            // `version` is omitted deliberately: it defaults to the bundle's
            // `CFBundleShortVersionString` and the kit adds the `v`, so What's New tracks the
            // shipped release without a second edit. Pass one only to pin notes to an older release.
            date: "2026-08-08",
            summary: L("app.whatsNew.summary"),
            // 2.5.0 moves About onto DragonKit 3's fixed-slot API. Only the user-visible half
            // belongs here — the rows changed shape, and two of them pointed somewhere wrong.
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                    L("app.whatsNew.fixed2"),
                ]),
            ]
        )
    }
}
