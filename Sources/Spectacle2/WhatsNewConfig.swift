import Foundation
import DragonKit

enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "v0.1.0",
            date: "2026-07-06",
            summary: L("app.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("app.whatsNew.added1"),
                ]),
            ]
        )
    }
}
