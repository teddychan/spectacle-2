import Foundation
import DragonKit

enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            // Single source of truth: the bundle's marketing version (no "v", no build number),
            // so What's New always matches the shipped release without a second edit.
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0",
            date: "2026-07-11",
            summary: L("app.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("app.whatsNew.added1"),
                    L("app.whatsNew.added2"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                ]),
            ]
        )
    }
}
