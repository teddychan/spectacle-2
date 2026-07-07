import Testing
import CoreGraphics
@testable import SpectacleCore

private let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)

@Test func geometryActionRecordsAndMoves() {
    var h = WindowHistory()
    let f0 = CGRect(x: 300, y: 200, width: 500, height: 400)
    let outcome = WindowActionResolver.resolve(
        action: .leftHalf, windowID: 1, currentFrame: f0,
        sourceVisibleFrame: frame, destinationVisibleFrame: frame, history: &h)
    #expect(outcome == .move(CGRect(x: 0, y: 0, width: 720, height: 900)))
    // pre-move frame was recorded → undoing returns it
    #expect(h.undo(current: CGRect(x: 0, y: 0, width: 720, height: 900), for: 1) == f0)
}

@Test func undoThenRedoRoundTrips_becauseNeitherRecords() {
    var h = WindowHistory()
    let f0 = CGRect(x: 300, y: 200, width: 500, height: 400)
    let half = CGRect(x: 0, y: 0, width: 720, height: 900)
    _ = WindowActionResolver.resolve(
        action: .leftHalf, windowID: 1, currentFrame: f0,
        sourceVisibleFrame: frame, destinationVisibleFrame: frame, history: &h)          // records f0
    let undo = WindowActionResolver.resolve(
        action: .undo, windowID: 1, currentFrame: half,
        sourceVisibleFrame: frame, destinationVisibleFrame: frame, history: &h)
    #expect(undo == .move(f0))                                                           // back to f0
    let redo = WindowActionResolver.resolve(
        action: .redo, windowID: 1, currentFrame: f0,
        sourceVisibleFrame: frame, destinationVisibleFrame: frame, history: &h)
    #expect(redo == .move(half))                                                         // redo survives
}

@Test func undoWithEmptyHistoryIsNoop() {
    var h = WindowHistory()
    let outcome = WindowActionResolver.resolve(
        action: .undo, windowID: 1, currentFrame: frame,
        sourceVisibleFrame: frame, destinationVisibleFrame: frame, history: &h)
    #expect(outcome == .noop)
}

@Test func sizeLimitedResizeKeepsRectUnchanged() {
    var h = WindowHistory()
    // makeSmaller on a window already at the ¼-screen minimum: the size adjuster returns the
    // ORIGINAL rect unchanged (Spectacle parity — a bounded resize is a no-op *move*, not nil).
    // So the resolver reports .move(sameRect); WindowCalculator only returns nil for undo/redo.
    let tiny = CGRect(x: 0, y: 0, width: 360, height: 600)   // width 360 == floor(1440/4) minimum
    let outcome = WindowActionResolver.resolve(
        action: .makeSmaller, windowID: 1, currentFrame: tiny,
        sourceVisibleFrame: frame, destinationVisibleFrame: frame, history: &h)
    #expect(outcome == .move(tiny))
}

@Test func displayDirectionMapping() {
    #expect(WindowActionResolver.displayDirection(for: .nextDisplay) == 1)
    #expect(WindowActionResolver.displayDirection(for: .previousDisplay) == -1)
    #expect(WindowActionResolver.displayDirection(for: .leftHalf) == 0)
    #expect(WindowActionResolver.displayDirection(for: .undo) == 0)
}

@Test func nextDisplayCentersOnDestinationWhenItFits() {
    var h = WindowHistory()
    let dest = CGRect(x: 1440, y: 0, width: 1000, height: 800)
    let win = CGRect(x: 10, y: 10, width: 400, height: 300)
    let outcome = WindowActionResolver.resolve(
        action: .nextDisplay, windowID: 1, currentFrame: win,
        sourceVisibleFrame: frame, destinationVisibleFrame: dest, history: &h)
    // fits → centered on dest: x = 1440 + (1000-400)/2 = 1740 ; y = (800-300)/2 = 250
    #expect(outcome == .move(CGRect(x: 1740, y: 250, width: 400, height: 300)))
}
