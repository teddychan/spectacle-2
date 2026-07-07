import Testing
@testable import SpectacleCore

@Test func cycleNeedsAtLeastTwoScreens() {
    #expect(ScreenCycle.destinationIndex(count: 1, current: 0, direction: 1) == nil)
    #expect(ScreenCycle.destinationIndex(count: 0, current: 0, direction: 1) == nil)
}

@Test func cycleWrapsForward() {
    #expect(ScreenCycle.destinationIndex(count: 3, current: 0, direction: 1) == 1)
    #expect(ScreenCycle.destinationIndex(count: 3, current: 2, direction: 1) == 0) // wrap
}

@Test func cycleWrapsBackward() {
    #expect(ScreenCycle.destinationIndex(count: 3, current: 0, direction: -1) == 2) // wrap
    #expect(ScreenCycle.destinationIndex(count: 2, current: 1, direction: -1) == 0)
}
