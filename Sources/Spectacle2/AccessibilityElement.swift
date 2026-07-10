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
        let h = primaryHeight()
        var axOrigin = CGPoint(x: cocoaRect.origin.x, y: h - cocoaRect.origin.y - cocoaRect.height)
        var size = cocoaRect.size
        // Set position, then size, then position again — some apps clamp size against the old
        // position on the first pass; the second position write lands them correctly.
        setPoint(window, kAXPositionAttribute, &axOrigin)
        setSize(window, kAXSizeAttribute, &size)
        setPoint(window, kAXPositionAttribute, &axOrigin)
    }

    /// The window element under a Cocoa (bottom-left, global) point, or nil. Uses the system-wide
    /// element and walks up to the enclosing window. Converts to AX's top-left global space first.
    func windowUnderCursor(atCocoaPoint p: CGPoint) -> AXUIElement? {
        guard !NSScreen.screens.isEmpty else { return nil }
        let axY = primaryHeight() - p.y                       // Cocoa bottom-left → AX top-left
        var hit: AXUIElement?
        let sys = AXUIElementCreateSystemWide()
        guard AXUIElementCopyElementAtPosition(sys, Float(p.x), Float(axY), &hit) == .success,
              var el = hit else { return nil }
        // Walk parents until we reach a window-role element (max a few hops).
        for _ in 0..<12 {
            if role(of: el) == (kAXWindowRole as String) { return el }
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parent) == .success,
                  let p = parent else { return nil }
            el = (p as! AXUIElement)
        }
        return nil
    }

    private func role(of el: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    // MARK: - AX value plumbing
    private func primaryHeight() -> CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

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
