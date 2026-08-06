import Testing
import Foundation
import SpectacleCore
@testable import Spectacle2

// ShortcutStore.load() merges DefaultShortcuts.map into a persisted map so actions added in a
// later app version still get a default binding. Each test uses its own UserDefaults suite
// (never the app's real suiteName) and removes it afterward so reruns start clean.

@MainActor
@Test func loadWithNothingPersistedCoversEveryAction() {
    let suiteName = "com.dragonapp.spectacle-2.tests.loadWithNothingPersistedCoversEveryAction"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    let map = ShortcutStore(suiteName: suiteName).load()

    for action in WindowAction.allCases {
        #expect(map[action] != nil, "missing binding for \(action)")
    }
}

@MainActor
@Test func loadMergesDefaultsForActionsOmittedFromThePersistedMap() {
    let suiteName = "com.dragonapp.spectacle-2.tests.loadMergesDefaultsForActionsOmittedFromThePersistedMap"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    var partial = DefaultShortcuts.map
    partial.removeValue(forKey: .center)
    partial.removeValue(forKey: .undo)
    let customBinding = Shortcut(keyCode: 99, modifiers: [.control])
    partial[.leftHalf] = customBinding

    let store = ShortcutStore(suiteName: suiteName)
    store.save(partial)
    let map = store.load()

    for action in WindowAction.allCases {
        #expect(map[action] != nil, "missing binding for \(action)")
    }
    #expect(map[.center] == DefaultShortcuts.map[.center])       // omitted -> filled from defaults
    #expect(map[.undo] == DefaultShortcuts.map[.undo])           // omitted -> filled from defaults
    #expect(map[.leftHalf] == customBinding)                     // persisted -> kept as stored
    #expect(map[.leftHalf] != DefaultShortcuts.map[.leftHalf])
}

@MainActor
@Test func restoreDefaultsReturnsAndPersistsExactlyDefaultShortcutsMap() {
    let suiteName = "com.dragonapp.spectacle-2.tests.restoreDefaultsReturnsAndPersistsExactlyDefaultShortcutsMap"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    let store = ShortcutStore(suiteName: suiteName)
    store.save([.center: Shortcut(keyCode: 1, modifiers: [])])   // seed something non-default

    let restored = store.restoreDefaults()
    #expect(restored == DefaultShortcuts.map)

    // A fresh store reading the same suite must see the persisted defaults.
    let reloaded = ShortcutStore(suiteName: suiteName).load()
    #expect(reloaded == DefaultShortcuts.map)
}
