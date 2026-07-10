import AppKit
import ApplicationServices
import SpectacleCore

/// Glues hot keys → geometry → AX, and owns undo/redo history.
/// Invariant: only geometry moves call `history.record`; undo/redo mutate history themselves.
@MainActor
final class WindowActionController {
    private var history = WindowHistory()
    private let ax = AccessibilityElement()
    private var hotKeys: HotKeyManager?

    /// Supplies the current gap on every action, so changing the setting takes effect immediately
    /// without re-registering hot keys. Defaults to no gap until the app wires it.
    var gapProvider: @MainActor () -> (size: CGFloat, skipTop: Bool) = { (0, false) }

    /// Starts the engine, returning the actions whose global hot key could not be registered
    /// (conflicts), so the UI can flag them.
    @discardableResult
    func start(with map: [WindowAction: Shortcut]) -> Set<WindowAction> {
        let hk = HotKeyManager { action in
            MainActor.assumeIsolated { [weak self] in self?.perform(action) }
        }
        let failed = hk.register(map)
        hotKeys = hk
        return failed
    }

    /// Re-registers after a rebind. Returns the actions that failed to register (conflicts).
    @discardableResult
    func updateShortcuts(_ map: [WindowAction: Shortcut]) -> Set<WindowAction> {
        hotKeys?.register(map) ?? []
    }

    func perform(_ action: WindowAction) {
        guard AXIsProcessTrusted() else { return }
        guard let window = ax.focusedWindow(), let current = ax.frame(of: window) else { return }
        let id = WindowID(element: window)
        let source = ScreenProvider.sourceVisibleFrame(for: current)

        // Decision logic lives in the pure, unit-tested WindowActionResolver (which enforces the
        // "only geometry moves record history" invariant); the controller just supplies I/O.
        let dir = WindowActionResolver.displayDirection(for: action)
        let dest = dir == 0 ? source : ScreenProvider.destinationVisibleFrame(for: current, direction: dir)
        let (gapSize, skipTop) = gapProvider()
        let outcome = WindowActionResolver.resolve(
            action: action, windowID: id, currentFrame: current,
            sourceVisibleFrame: source, destinationVisibleFrame: dest,
            gap: gapSize, skipGapTopEdge: skipTop, history: &history)
        if case .move(let newRect) = outcome { ax.setFrame(newRect, of: window) }
    }
}
