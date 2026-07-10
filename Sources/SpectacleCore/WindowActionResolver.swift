import CoreGraphics

/// The decision produced for one window action: apply a frame, or do nothing.
public enum WindowActionOutcome: Equatable, Sendable {
    case move(CGRect)
    case noop
}

/// Pure decision logic for a window action. The app's `WindowActionController` is a thin I/O
/// shell around this: it gathers the current frame and screen frames, calls `resolve`, and
/// applies the outcome. Keeping the decision here (no AppKit/AX/Carbon) makes the full pipeline
/// unit-testable and enforces the invariant that **only geometry moves record history** —
/// undo/redo mutate history themselves and must never `record` (which would clear redo).
public enum WindowActionResolver {
    /// +1 for Next Display, -1 for Previous Display, 0 otherwise. The app uses this to pick the
    /// destination screen's visible frame before calling `resolve`.
    public static func displayDirection(for action: WindowAction) -> Int {
        switch action {
        case .nextDisplay: return 1
        case .previousDisplay: return -1
        default: return 0
        }
    }

    public static func resolve<ID: Hashable>(
        action: WindowAction,
        windowID: ID,
        currentFrame: CGRect,
        sourceVisibleFrame: CGRect,
        destinationVisibleFrame: CGRect,
        gap: CGFloat = 0,
        skipGapTopEdge: Bool = false,
        history: inout WindowHistory
    ) -> WindowActionOutcome {
        switch action {
        case .undo:
            return history.undo(current: currentFrame, for: windowID).map(WindowActionOutcome.move) ?? .noop
        case .redo:
            return history.redo(current: currentFrame, for: windowID).map(WindowActionOutcome.move) ?? .noop
        default:
            let input = CalculationInput(
                windowRect: currentFrame,
                sourceVisibleFrame: sourceVisibleFrame,
                destinationVisibleFrame: destinationVisibleFrame,
                gap: gap,
                skipGapTopEdge: skipGapTopEdge
            )
            guard let newRect = WindowCalculator.calculate(action, input) else { return .noop }
            history.record(currentFrame, for: windowID)
            return .move(newRect)
        }
    }
}
