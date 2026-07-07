import SwiftUI
import DragonKit
import SpectacleCore

struct ShortcutsPane: SettingsPane {
    let id = "shortcuts"
    let title = "app.pane.shortcuts"
    let systemImage = "keyboard"
    let store: ShortcutStore
    /// Applies the new map to the hot-key engine and returns the actions that failed to
    /// register (conflicts), which the pane flags on the affected rows.
    let onChange: (ShortcutStore.Map) -> Set<WindowAction>

    var paneBody: some View { ShortcutsPaneView(store: store, onChange: onChange) }
}

private struct ShortcutsPaneView: View {
    let store: ShortcutStore
    let onChange: (ShortcutStore.Map) -> Set<WindowAction>
    @State private var map: ShortcutStore.Map = [:]
    @State private var conflicts: Set<WindowAction> = []

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
                        row(for: action)
                    }
                }
            }
            DragonSection {
                Button(L("app.shortcuts.restoreDefaults")) {
                    map = store.restoreDefaults()
                    conflicts = onChange(map)
                }
            }
        }
        .onAppear {
            map = store.load()
            conflicts = onChange(map)
        }
    }

    @ViewBuilder
    private func row(for action: WindowAction) -> some View {
        let content = HStack {
            Text(L("app.action.\(action.rawValue)"))
            Spacer()
            ShortcutRecorderField(
                shortcut: Binding(
                    get: { map[action] },
                    set: { map[action] = $0 }
                ),
                onChange: { _ in
                    store.save(map)
                    conflicts = onChange(map)
                }
            )
            .frame(width: 200)
        }
        if conflicts.contains(action) {
            content.dragonAnnotation(LocalizedStringKey(L("app.shortcuts.conflict")))
        } else {
            content
        }
    }
}
