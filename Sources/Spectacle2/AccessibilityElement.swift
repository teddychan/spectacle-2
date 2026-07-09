import AppKit
import ApplicationServices

/// Stable identity for a window across AX calls (AX returns CFEqual-equal refs for the same
/// on-screen window). Used to key undo/redo history.
struct WindowID: Hashable {
    let element: AXUIElement
    static func == (lhs: WindowID, rhs: WindowID) -> Bool { CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

/// Reads/writes the frontmost app's focused-window frame. Owns the single AX↔Cocoa Y-flip.
final class AccessibilityElement {
    func focusedWindow() -> AXUIElement? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let v = value else { return nil }
        return (v as! AXUIElement)
    }

    func frame(of window: AXUIElement) -> CGRect? {
        guard !NSScreen.screens.isEmpty else { return nil }
        guard let pos = point(window, kAXPositionAttribute),
              let size = size(window, kAXSizeAttribute) else { return nil }
        let h = primaryHeight()
        return CGRect(x: pos.x, y: h - pos.y - size.height, width: size.width, height: size.height)
    }

    func setFrame(_ cocoaRect: CGRect, of window: AXUIElement) {
        // A window we can't reposition (native full-screen, some modal/utility windows) is left
        // alone rather than half-moved. Position is the anchor for every action, so if it isn't
        // settable there's nothing safe to do.
        guard isSettable(window, kAXPositionAttribute) else { return }
        let h = primaryHeight()
        var axOrigin = CGPoint(x: cocoaRect.origin.x, y: h - cocoaRect.origin.y - cocoaRect.height)
        var size = cocoaRect.size
        setPoint(window, kAXPositionAttribute, &axOrigin)
        // Only resize windows that allow it — fixed-size / fixed-aspect windows reject the write,
        // so skipping it keeps the move to a clean reposition instead of a fought, clamped resize.
        // Set position, then size, then position again: some apps clamp size against the old
        // position on the first pass; the second position write lands them correctly.
        if isSettable(window, kAXSizeAttribute) {
            setSize(window, kAXSizeAttribute, &size)
            setPoint(window, kAXPositionAttribute, &axOrigin)
        }
    }

    // MARK: - AX value plumbing

    /// The AX global coordinate space is anchored at the top-left of the *primary* screen — the
    /// one at origin (0,0) carrying the menu bar. That's conventionally `screens.first`, but pick
    /// it by origin so a reordered `screens` array on a multi-display setup can't skew the flip.
    private func primaryHeight() -> CGFloat {
        let screens = NSScreen.screens
        return (screens.first { $0.frame.origin == .zero } ?? screens.first)?.frame.height ?? 0
    }

    private func isSettable(_ el: AXUIElement, _ attr: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(el, attr as CFString, &settable) == .success && settable.boolValue
    }

    private func point(_ el: AXUIElement, _ attr: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success, let v = value else { return nil }
        var p = CGPoint.zero
        return AXValueGetValue((v as! AXValue), .cgPoint, &p) ? p : nil
    }
    private func size(_ el: AXUIElement, _ attr: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success, let v = value else { return nil }
        var s = CGSize.zero
        return AXValueGetValue((v as! AXValue), .cgSize, &s) ? s : nil
    }
    private func setPoint(_ el: AXUIElement, _ attr: String, _ p: inout CGPoint) {
        if let v = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(el, attr as CFString, v) }
    }
    private func setSize(_ el: AXUIElement, _ attr: String, _ s: inout CGSize) {
        if let v = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(el, attr as CFString, v) }
    }
}
