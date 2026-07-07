import Foundation
import DragonKit

enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.0.1",
            date: "2026-07-07",
            summary: L("app.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                ]),
            ]
        )
    }
}
