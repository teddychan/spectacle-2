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
            // Everything here comes from the DragonKit 2.3.0 bump rather than this app's own
            // code, but it is all user-visible, so it belongs in the pane the same as any other
            // change — where it came from is the changelog's business, not the user's.
            sections: [
                ChangeSection(kind: .improved, entries: [
                    L("app.whatsNew.improved1"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                    L("app.whatsNew.fixed2"),
                ]),
                ChangeSection(kind: .removed, entries: [
                    L("app.whatsNew.removed1"),
                ]),
            ]
        )
    }
}
