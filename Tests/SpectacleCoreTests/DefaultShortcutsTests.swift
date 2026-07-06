import Testing
@testable import SpectacleCore

@Test func everyActionHasADefault() {
    for action in WindowAction.allCases {
        #expect(DefaultShortcuts.map[action] != nil, "missing default for \(action)")
    }
}

@Test func classicBindingsAreCorrect() {
    #expect(DefaultShortcuts.map[.center] == Shortcut(keyCode: 8, modifiers: [.option, .command]))       // ⌥⌘C
    #expect(DefaultShortcuts.map[.leftHalf]?.displayString == "⌥⌘←")
    #expect(DefaultShortcuts.map[.lowerRight]?.displayString == "⌃⇧⌘→")
    #expect(DefaultShortcuts.map[.redo]?.displayString == "⌥⇧⌘Z")
}
