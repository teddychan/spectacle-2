import Testing
import Foundation
@testable import SpectacleCore

@Test func displayStringOrdersModifiersThenKey() {
    // ⌥⌘C : option+command, keyCode 8 (C)
    let s = Shortcut(keyCode: 8, modifiers: [.option, .command])
    #expect(s.displayString == "⌥⌘C")
}

@Test func arrowKeyDisplay() {
    let left = Shortcut(keyCode: 123, modifiers: [.option, .command])
    #expect(left.displayString == "⌥⌘←")
}

@Test func modifierFlagsCodableRoundTrip() throws {
    let flags: ModifierFlags = [.control, .shift, .command]
    let data = try JSONEncoder().encode(flags)
    #expect(try JSONDecoder().decode(ModifierFlags.self, from: data) == flags)
}
