import CoreGraphics

/// Per-window undo/redo of prior frames. `WindowID` is any Hashable the app supplies.
///
/// Deliberately not `Sendable`. The keys are `AnyHashable`-wrapped window identities, which in the
/// app carry an `AXUIElement`, so the previous `@unchecked Sendable` and its claim that this holds
/// "only `CGRect` stacks" described the wrong invariant. Nothing needs the conformance: the real
/// invariant is main-actor confinement — every mutation goes through the `@MainActor`
/// `WindowActionController`, and `WindowActionResolver` only borrows it `inout`.
public struct WindowHistory {
    private var undoStacks: [AnyHashable: [CGRect]] = [:]
    private var redoStacks: [AnyHashable: [CGRect]] = [:]

    // Per-window cap on undo depth. Without this, a window that gets moved repeatedly over a
    // long uptime accumulates one CGRect per move forever. Once a window's stack exceeds the
    // cap we drop its oldest entry, so the oldest history becomes permanently unreachable by
    // design — that's the intended tradeoff for bounded memory.
    private static let maxUndoDepth = 50

    public init() {}

    /// Called only for geometry moves: pushes the pre-move frame and clears redo.
    public mutating func record<ID: Hashable>(_ frame: CGRect, for id: ID) {
        let key = AnyHashable(id)
        var stack = undoStacks[key] ?? []
        stack.append(frame)
        if stack.count > Self.maxUndoDepth { stack.removeFirst(stack.count - Self.maxUndoDepth) }
        undoStacks[key] = stack
        redoStacks[key] = []
    }

    public mutating func undo<ID: Hashable>(current: CGRect, for id: ID) -> CGRect? {
        let key = AnyHashable(id)
        guard var stack = undoStacks[key], let previous = stack.popLast() else { return nil }
        undoStacks[key] = stack
        redoStacks[key, default: []].append(current)
        return previous
    }

    public mutating func redo<ID: Hashable>(current: CGRect, for id: ID) -> CGRect? {
        let key = AnyHashable(id)
        guard var stack = redoStacks[key], let next = stack.popLast() else { return nil }
        redoStacks[key] = stack
        undoStacks[key, default: []].append(current)
        return next
    }
}
