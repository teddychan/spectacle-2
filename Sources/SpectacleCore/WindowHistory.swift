import CoreGraphics

/// Per-window undo/redo of prior frames. `WindowID` is any Hashable the app supplies.
/// `@unchecked`: a value type holding only `AnyHashable`-keyed `CGRect` stacks — actually
/// Sendable, but the compiler can't prove it because `AnyHashable` isn't conditionally Sendable.
public struct WindowHistory: @unchecked Sendable {
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
