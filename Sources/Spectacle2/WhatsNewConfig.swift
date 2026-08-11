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
            // 2.5.4 does claim a fix, unlike 2.5.3 and 2.5.2: About gains its "Open-source
            // licenses" row. The pane has listed `Sparkle → MIT` since 2.5.0 while `licensesURL`
            // sat nil, so it named a bundled component and offered no way to read that component's
            // notice — found by comparing all five Dragon apps' About panes side by side, where
            // this app and the sample app were the two with the gap. DragonKit 4.0.0 makes the URL
            // required, which is what stops the row going missing again.
            //
            // The kit bump is stated too, and separately, because it is the only *other* thing a
            // user can observe: About's "Built with · DragonKit vX.Y.Z" row. Nothing else in 4.0.0
            // reaches this app's UI — its other change folds the upstream project's URL into
            // `OriginalWork`, which this app already supplied both halves of, so the Original
            // project and Based on rows render exactly as they did in 2.5.3.
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
