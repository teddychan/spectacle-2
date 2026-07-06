import Testing
@testable import SpectacleCore

@Test func hasEighteenActions() {
    #expect(WindowAction.allCases.count == 18)
}

@Test func geometryActionsExcludeHistory() {
    #expect(!WindowAction.geometryActions.contains(.undo))
    #expect(!WindowAction.geometryActions.contains(.redo))
    #expect(WindowAction.geometryActions.count == 16)
}
