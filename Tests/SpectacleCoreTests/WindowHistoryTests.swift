import Testing
import CoreGraphics
@testable import SpectacleCore

private let a = CGRect(x: 0, y: 0, width: 100, height: 100)
private let b = CGRect(x: 10, y: 10, width: 100, height: 100)
private let c = CGRect(x: 20, y: 20, width: 100, height: 100)

@Test func undoRestoresPreviousAndRedoReapplies() {
    var h = WindowHistory()
    let id = 1
    h.record(a, for: id)          // move a→b
    h.record(b, for: id)          // move b→c ; window now at c
    #expect(h.undo(current: c, for: id) == b)
    #expect(h.undo(current: b, for: id) == a)
    #expect(h.undo(current: a, for: id) == nil)   // empty
    #expect(h.redo(current: a, for: id) == b)
    #expect(h.redo(current: b, for: id) == c)
    #expect(h.redo(current: c, for: id) == nil)
}

@Test func recordClearsRedo() {
    var h = WindowHistory()
    let id = 1
    h.record(a, for: id)
    _ = h.undo(current: b, for: id)   // redo stack now has b
    h.record(a, for: id)              // a new move must clear redo
    #expect(h.redo(current: a, for: id) == nil)
}

@Test func historyIsPerWindow() {
    var h = WindowHistory()
    h.record(a, for: 1)
    #expect(h.undo(current: b, for: 2) == nil)   // different window, empty
    #expect(h.undo(current: b, for: 1) == a)
}
