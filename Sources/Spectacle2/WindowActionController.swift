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
    /// The active shortcut map, kept so hot keys can be restored after a recording session.
    private var currentMap: [WindowAction: Shortcut] = [:]

    /// Starts the engine, returning the actions whose global hot key could not be registered
    /// (conflicts), so the UI can flag them.
    @discardableResult
    func start(with map: [WindowAction: Shortcut]) -> Set<WindowAction> {
        currentMap = map
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
        currentMap = map
        return hotKeys?.register(map) ?? []
    }

    /// Suspends global hot keys while a shortcut is being recorded, so pressing a combo that is
    /// already bound lands in the recorder instead of triggering that action; restores the active
    /// map when recording ends. Must be balanced — every `true` is followed by a `false` (the
    /// recorder guarantees this even if its window closes mid-recording).
    func setRecording(_ recording: Bool) {
        if recording {
            hotKeys?.unregisterAll()
        } else {
            _ = hotKeys?.register(currentMap)
        }
    }

    func perform(_ action: WindowAction) {
        // Without Accessibility permission every action is a silent no-op. Trigger the system
        // prompt so the first hot-key press explains why nothing happened and offers to open
        // System Settings; macOS shows it once and suppresses it thereafter until granted.
        guard ensureTrusted() else { return }
        guard let window = ax.focusedWindow(), let current = ax.frame(of: window) else { return }
        let id = WindowID(element: window)
        let source = ScreenProvider.sourceVisibleFrame(for: current)

        // Decision logic lives in the pure, unit-tested WindowActionResolver (which enforces the
        // "only geometry moves record history" invariant); the controller just supplies I/O.
        let dir = WindowActionResolver.displayDirection(for: action)
        let dest = dir == 0 ? source : ScreenProvider.destinationVisibleFrame(for: current, direction: dir)
        let outcome = WindowActionResolver.resolve(
            action: action, windowID: id, currentFrame: current,
            sourceVisibleFrame: source, destinationVisibleFrame: dest, history: &history)
        // Skip the AX write when the frame wouldn't change (e.g. Fullscreen/Center pressed twice,
        // or a bounded resize already at its limit): the round-trip is pure overhead. History
        // semantics are untouched — the resolver has already recorded per its parity rules.
        if case .move(let newRect) = outcome, newRect != current { ax.setFrame(newRect, of: window) }
    }

    /// Whether Accessibility permission is granted; when it isn't, asks macOS to show its
    /// "grant access" prompt (a no-op if one is already pending or the user dismissed it).
    private func ensureTrusted() -> Bool {
        if AXIsProcessTrusted() { return true }
        // Literal key value of `kAXTrustedCheckOptionPrompt` — referencing the imported global
        // `var` directly isn't concurrency-safe under Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return false
    }
}
