import AppKit
import ApplicationServices
import SpectacleCore

/// Rectangle-parity drag-to-edge snapping. Passive NSEvent monitors observe the left mouse; on a
/// real move it previews the target zone and, on release, snaps the window under the cursor.
@MainActor
final class DragSnapController {
    private let controller: WindowActionController
    private let gapProvider: @MainActor () -> WindowGap
    private let overlay = SnapPreviewOverlay()

    private var localMonitor: Any?
    private var globalMonitor: Any?

    // Per-drag state.
    private var window: AXUIElement?
    private var windowID: WindowID?
    private var initialFrame: CGRect?
    private var moving = false
    private var currentTarget: SnapTarget?
    private var lastBottomColumn: SnapGeometry.ThirdColumn?
    private var restoreRects: [WindowID: CGRect] = [:]   // pre-snap sizes, persisted across drags for unsnap-restore
    // Insertion order for `restoreRects`, oldest first. A snapped window whose entry is never
    // consumed (e.g. it's closed instead of dragged off its snap) would otherwise sit here
    // forever, retaining a stale AXUIElement. We evict by age rather than by probing whether the
    // window is still alive, because a liveness probe is itself AX IPC on every mouse-up — the
    // exact per-event cost this drag path exists to avoid.
    private var restoreOrder: [WindowID] = []
    private let restoreRectsCap = 32

    init(controller: WindowActionController, gapProvider: @escaping @MainActor () -> WindowGap) {
        self.controller = controller
        self.gapProvider = gapProvider
    }

    var isRunning: Bool { globalMonitor != nil }

    func start() {
        guard globalMonitor == nil, AXIsProcessTrusted() else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .leftMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] e in
            self?.handle(e)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] e in
            self?.handle(e); return e
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        resetDrag()
    }

    private func handle(_ e: NSEvent) {
        switch e.type {
        case .leftMouseDown: beginCapture()
        case .leftMouseDragged: continueDrag()
        case .leftMouseUp: endDrag()
        default: break
        }
    }

    private func beginCapture() {
        // Capture the window under the cursor; snapping arms only once it actually moves.
        let p = NSEvent.mouseLocation
        guard let hit = controller.windowUnderCursor(atCocoaPoint: p) else { resetDrag(); return }
        window = hit.window; windowID = hit.id; initialFrame = hit.frame
        moving = false; currentTarget = nil; lastBottomColumn = nil
    }

    private func continueDrag() {
        guard let window, let windowID, let initial = initialFrame else { return }

        if !moving {
            // The AX frame read is deliberately confined to this arming phase: `frame(of:)` is
            // synchronous cross-process Accessibility IPC on the main thread, and `live` is only
            // needed here (for the move-vs-resize check and the unsnap-restore origin/size math).
            // Once armed we never read it again, so doing this on every .leftMouseDragged event
            // would pay that IPC cost per pixel of drag for no benefit.
            guard let live = controller.frame(of: window) else { return }
            // Arm only on a real move (origin changed, size unchanged = a move, not a resize).
            guard live.origin != initial.origin,
                  abs(live.width - initial.width) < 1, abs(live.height - initial.height) < 1 else { return }
            moving = true
            unsnapRestoreIfNeeded(window: window, id: windowID, live: live)
        }

        let cursor = NSEvent.mouseLocation
        guard let screen = screenFrame(containing: cursor), let zone = SnapGeometry.zone(for: cursor, in: screen) else {
            currentTarget = nil; lastBottomColumn = nil; overlay.hide(); return
        }
        let mapped = SnapGeometry.target(for: zone, cursor: cursor, screen: screen, previousBottomColumn: lastBottomColumn)
        let target = mapped.target
        lastBottomColumn = mapped.bottomColumn
        currentTarget = target
        let vf = visibleFrame(forScreenFrame: screen)
        overlay.show(at: SnapGeometry.rect(target, visibleFrame: vf, gap: gapProvider()))
    }

    private func endDrag() {
        defer { resetDrag() }
        overlay.hide()
        guard moving, let window, let windowID,
              let live = controller.frame(of: window),
              let screen = screenFrame(containing: NSEvent.mouseLocation) else { return }
        // Prefer the tracked zone; otherwise re-check under the cursor (fast-drag fallback).
        let target: SnapTarget
        if let t = currentTarget {
            target = t
        } else if let zone = SnapGeometry.zone(for: NSEvent.mouseLocation, in: screen) {
            let mapped = SnapGeometry.target(
                for: zone, cursor: NSEvent.mouseLocation, screen: screen, previousBottomColumn: lastBottomColumn)
            target = mapped.target
            lastBottomColumn = mapped.bottomColumn
        } else {
            return
        }
        let vf = visibleFrame(forScreenFrame: screen)
        let rect = SnapGeometry.rect(target, visibleFrame: vf, gap: gapProvider())
        rememberRestoreRect(live, for: windowID)   // remember pre-snap size
        controller.apply(rect, to: window, id: windowID, currentFrame: live, record: true)
    }

    // MARK: - Unsnap-restore

    private func unsnapRestoreIfNeeded(window: AXUIElement, id: WindowID, live: CGRect) {
        guard let restore = restoreRects[id] else { return }
        var r = restore
        let cursor = NSEvent.mouseLocation
        r.origin.x = min(max(cursor.x - r.width / 2, live.minX), live.maxX - r.width)
        r.origin.y = live.maxY - r.height
        controller.apply(r, to: window, id: id, currentFrame: live, record: false)
        restoreRects[id] = nil
        restoreOrder.removeAll { $0 == id }
    }

    // Inserts a pre-snap rect (only if one isn't already recorded for `id`), tracking insertion
    // order so we can evict the oldest entry once the map exceeds `restoreRectsCap`. Eviction is
    // by age, not by an AX liveness check, on purpose — see the comment on `restoreOrder`.
    private func rememberRestoreRect(_ rect: CGRect, for id: WindowID) {
        guard restoreRects[id] == nil else { return }
        restoreRects[id] = rect
        restoreOrder.append(id)
        if restoreOrder.count > restoreRectsCap {
            let oldest = restoreOrder.removeFirst()
            restoreRects[oldest] = nil
        }
    }

    // MARK: - Screen helpers

    private func screenFrame(containing p: CGPoint) -> CGRect? {
        NSScreen.screens.first { $0.frame.contains(p) }?.frame
    }
    private func visibleFrame(forScreenFrame f: CGRect) -> CGRect {
        (NSScreen.screens.first { $0.frame == f } ?? NSScreen.main)?.visibleFrame ?? f
    }

    private func resetDrag() {
        window = nil; windowID = nil; initialFrame = nil
        moving = false; currentTarget = nil; lastBottomColumn = nil
    }
}
