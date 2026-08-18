import Foundation
import DragonKit

enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            // `version` is omitted deliberately: it defaults to the bundle's
            // `CFBundleShortVersionString` and the kit adds the `v`, so What's New tracks the
            // shipped release without a second edit. Pass one only to pin notes to an older release.
            date: "2026-08-18",
            summary: L("app.whatsNew.summary"),
            // 2.5.6 is a maintenance release and says so. Everything in it came from two commits
            // that changed no app behaviour:
            //
            //   * the DragonKit floor moved 4.0.0 → 4.1.0 (#40). The kit owns Settings, About,
            //     What's New and the updater, so a bump is worth naming even when no pane moves —
            //     2.5.4's `.changed` entry existed because that bump DID move About's "Built with"
            //     row. 4.1.0 does not, so the entry says the version changed and the panes did not,
            //     rather than dressing a floor bump up as an improvement.
            //   * the bundle inputs moved to `App/` (#39, CONFORMANCE §R16), and `LICENSE` now
            //     names Eric Czarny for the original Spectacle and Teddy Chan for this
            //     reimplementation (#38). Both are source-tree facts; neither is reachable from
            //     the running app, so they are one honest "housekeeping" line and not two claims.
            //
            // No `.fixed` section: nothing user-facing was fixed since 2.5.5, and `.improved`
            // would be a claim this release cannot support. `app.whatsNew.fixed1` is removed from
            // the seven .strings files rather than left holding 2.5.5's sentence — the same
            // treatment `app.whatsNew.changed1` got a release ago, for the same reason.
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                    L("app.whatsNew.changed2"),
                ]),
            ]
        )
    }
}
