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
            // One section, deliberately. 2.2.2 changes nothing a user can observe, so there is
            // nothing honest to list under Added, Improved or Fixed — padding this pane to look
            // like a bigger release is exactly what it exists not to do.
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                ]),
            ]
        )
    }
}
