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
            // 2.5.3 carries exactly one commit: the DragonKit pin moved 3.3.0 -> 3.4.0 to satisfy
            // CONFORMANCE §R10, which requires the declared pin to be at least the kit's newest
            // tag, so publishing v3.4.0 put this app in violation the moment it landed. Nothing in
            // 3.4.0 is adopted here — it adds `LanguagePicker(languages:onChange:)` with both
            // parameters defaulted, for an app translated into fewer languages than the kit ships,
            // and Spectacle 2 never calls it. So there is one entry and it claims no fix: About's
            // "Built with · DragonKit vX.Y.Z" row is the only thing a user can see change, and
            // 2.5.2 already set the precedent of saying that plainly instead of padding the notes
            // to look like a feature release.
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                ]),
            ]
        )
    }
}
