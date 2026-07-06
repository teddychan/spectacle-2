import CoreGraphics

/// Per-window undo/redo of prior frames. `WindowID` is any Hashable the app supplies.
/// `@unchecked`: a value type holding only `AnyHashable`-keyed `CGRect` stacks — actually
/// Sendable, but the compiler can't prove it because `AnyHashable` isn't conditionally Sendable.
public struct WindowHistory: @unchecked Sendable {
    private var undoStacks: [AnyHashable: [CGRect]] = [:]
    private var redoStacks: [AnyHashable: [CGRect]] = [:]

    public init() {}

    /// Called only for geometry moves: pushes the pre-move frame and clears redo.
    public mutating func record<ID: Hashable>(_ frame: CGRect, for id: ID) {
        undoStacks[AnyHashable(id), default: []].append(frame)
        redoStacks[AnyHashable(id)] = []
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
