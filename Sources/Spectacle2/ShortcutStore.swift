import Foundation
import DragonKit
import SpectacleCore

/// Persists the action→shortcut map in the app's settings suite (so Backup & Restore captures it).
@MainActor
final class ShortcutStore {
    typealias Map = [WindowAction: Shortcut]
    private let store: DragonSettingsStore<Map>

    init(suiteName: String) {
        store = DragonSettingsStore(suiteName: suiteName, defaultValue: DefaultShortcuts.map)
    }

    func load() -> Map {
        // Merge in any actions missing from a persisted older map so new actions get defaults.
        var map = store.load()
        for (action, sc) in DefaultShortcuts.map where map[action] == nil { map[action] = sc }
        return map
    }
    func save(_ map: Map) { store.save(map) }
    func restoreDefaults() -> Map { store.save(DefaultShortcuts.map); return DefaultShortcuts.map }
}
