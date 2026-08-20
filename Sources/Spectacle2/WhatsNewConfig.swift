import Foundation
import DragonKit

enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            // `version` is omitted deliberately: it defaults to the bundle's
            // `CFBundleShortVersionString` and the kit adds the `v`, so What's New tracks the
            // shipped release without a second edit. Pass one only to pin notes to an older release.
            date: "2026-08-20",
            summary: L("app.whatsNew.summary"),
            // 2.5.7 carries exactly one user-facing change, and it arrives from the kit rather
            // than from this app: DragonKit 4.1.1 makes Uninstall refuse to run when a second
            // copy of the app is on the Mac. Worth a `.fixed` entry even though no Spectacle 2
            // source changed, because the behaviour a user meets is different — the opposite of
            // 2.5.6's floor bump, which moved a version and no pane, and said so.
            //
            // `.fixed` leads. The kit bump is real but secondary, and listing it first would put
            // the version number above the safety fix it delivered.
            //
            // 4.1.1's OTHER fix is deliberately absent: it silenced a raw developer error behind
            // Settings ▸ Updates that only a local Debug build could reach, so no user of this app
            // could have hit it. It is in CHANGELOG.md, where source-tree facts belong. Claiming
            // it here would describe a defect nobody experienced as though it had been theirs.
            //
            // `app.whatsNew.changed2` — 2.5.6's housekeeping line — is deleted from the seven
            // .strings files rather than left holding a sentence about the previous release. Same
            // treatment `fixed1` got a release ago, for the same reason.
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                ]),
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                ]),
            ]
        )
    }
}
