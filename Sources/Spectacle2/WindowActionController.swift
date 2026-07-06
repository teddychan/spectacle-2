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

    func start(with map: [WindowAction: Shortcut]) {
        let hk = HotKeyManager { action in
            MainActor.assumeIsolated { [weak self] in self?.perform(action) }
        }
        hk.register(map)
        hotKeys = hk
    }

    func updateShortcuts(_ map: [WindowAction: Shortcut]) { hotKeys?.register(map) }

    func perform(_ action: WindowAction) {
        guard AXIsProcessTrusted() else { return }
        guard let window = ax.focusedWindow(), let current = ax.frame(of: window) else { return }
        let id = WindowID(element: window)
        let source = ScreenProvider.sourceVisibleFrame(for: current)

        switch action {
        case .undo:
            if let f = history.undo(current: current, for: id) { ax.setFrame(f, of: window) }
        case .redo:
            if let f = history.redo(current: current, for: id) { ax.setFrame(f, of: window) }
        default:
            let dir = action == .nextDisplay ? 1 : (action == .previousDisplay ? -1 : 0)
            let dest = dir == 0 ? source : ScreenProvider.destinationVisibleFrame(for: current, direction: dir)
            let input = CalculationInput(windowRect: current, sourceVisibleFrame: source, destinationVisibleFrame: dest)
            guard let newRect = WindowCalculator.calculate(action, input) else { return }
            history.record(current, for: id)          // pre-move frame; only geometry moves record
            ax.setFrame(newRect, of: window)
        }
    }
}
