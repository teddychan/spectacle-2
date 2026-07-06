import SwiftUI
import DragonKit
import SpectacleCore

struct ShortcutsPane: SettingsPane {
    let id = "shortcuts"
    let title = "app.pane.shortcuts"
    let systemImage = "keyboard"
    let store: ShortcutStore
    let onChange: (ShortcutStore.Map) -> Void

    var paneBody: some View { ShortcutsPaneView(store: store, onChange: onChange) }
}

private struct ShortcutsPaneView: View {
    let store: ShortcutStore
    let onChange: (ShortcutStore.Map) -> Void
    @State private var map: ShortcutStore.Map = [:]

    // Sidebar grouping mirrors Spectacle's preferences layout.
    private let groups: [(String, [WindowAction])] = [
        ("app.shortcuts.section.halves", [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        ("app.shortcuts.section.corners", [.upperLeft, .upperRight, .lowerLeft, .lowerRight]),
        ("app.shortcuts.section.thirds", [.nextThird, .previousThird]),
        ("app.shortcuts.section.sizing", [.center, .fullscreen, .makeLarger, .makeSmaller]),
        ("app.shortcuts.section.displays", [.nextDisplay, .previousDisplay]),
        ("app.shortcuts.section.history", [.undo, .redo]),
    ]

    var body: some View {
        DragonForm {
            ForEach(groups, id: \.0) { section in
                DragonSection(LocalizedStringKey(L(section.0))) {
                    ForEach(section.1, id: \.self) { action in
                        HStack {
                            Text(L("app.action.\(action.rawValue)"))
                            Spacer()
                            ShortcutRecorderField(
                                shortcut: Binding(
                                    get: { map[action] },
                                    set: { map[action] = $0 }
                                ),
                                onChange: { _ in store.save(map); onChange(map) }
                            )
                            .frame(width: 200)
                        }
                    }
                }
            }
            DragonSection {
                Button(L("app.shortcuts.restoreDefaults")) {
                    map = store.restoreDefaults(); onChange(map)
                }
            }
        }
        .onAppear { map = store.load() }
    }
}
