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
        guard let window, let windowID, let initial = initialFrame,
              let live = controller.frame(of: window) else { return }

        if !moving {
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
        let target = mapZoneToTarget(zone, cursor: cursor, screen: screen)
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
            target = mapZoneToTarget(zone, cursor: NSEvent.mouseLocation, screen: screen)
        } else {
            return
        }
        let vf = visibleFrame(forScreenFrame: screen)
        let rect = SnapGeometry.rect(target, visibleFrame: vf, gap: gapProvider())
        if restoreRects[windowID] == nil { restoreRects[windowID] = live }   // remember pre-snap size
        controller.apply(rect, to: window, id: windowID, currentFrame: live, record: true)
    }

    // MARK: - Zone → target (incl. bottom-edge thirds + two-thirds promotion)

    private func mapZoneToTarget(_ zone: SnapGeometry.SnapZone, cursor: CGPoint, screen: CGRect) -> SnapTarget {
        switch zone {
        case .top: return .maximize
        case .topLeft: return .topLeft
        case .topRight: return .topRight
        case .bottomLeft: return .bottomLeft
        case .bottomRight: return .bottomRight
        case .left:
            return SnapGeometry.sideEdgeHalf(cursorY: cursor.y, in: screen) ?? .leftHalf
        case .right:
            return SnapGeometry.sideEdgeHalf(cursorY: cursor.y, in: screen) ?? .rightHalf
        case .bottom:
            let col = SnapGeometry.bottomEdgeThird(cursorX: cursor.x, in: screen)
            defer { lastBottomColumn = col }
            // Two-thirds promotion: entering the center third from a side third widens to two-thirds.
            if col == .center, let prev = lastBottomColumn {
                if prev == .first { return .firstTwoThirds }
                if prev == .last { return .lastTwoThirds }
            }
            switch col {
            case .first: return .firstThird
            case .center: return .centerThird
            case .last: return .lastThird
            }
        }
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
