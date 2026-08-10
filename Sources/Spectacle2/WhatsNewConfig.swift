import Foundation
import DragonKit

enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            // `version` is omitted deliberately: it defaults to the bundle's
            // `CFBundleShortVersionString` and the kit adds the `v`, so What's New tracks the
            // shipped release without a second edit. Pass one only to pin notes to an older release.
            date: "2026-08-10",
            summary: L("app.whatsNew.summary"),
            // 2.5.2 is maintenance-only from a user's seat, and says so rather than dressing up
            // an empty release. Everything it fixes — a version field that carried "(Debug)", a
            // debug build that could still reach the production appcast — is in the local build
            // that runs beside the released app, so it changes nothing about the shipped one.
            // The kit bump is the single item here because About reports it ("Built with ·
            // DragonKit vX.Y.Z"), which makes it the one change a user can actually see.
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                ]),
            ]
        )
    }
}
