import AppKit

/// A translucent borderless window that previews the snap target during a drag. Styling mirrors
/// Rectangle's footprint: ~30% black fill, light-gray 2pt border, rounded corners.
@MainActor
final class SnapPreviewOverlay {
    private let window: NSWindow
    private let box: NSBox

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .modalPanel
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.transient, .canJoinAllSpaces, .ignoresCycle]

        box = NSBox()
        box.boxType = .custom
        box.borderWidth = 2
        box.borderColor = .lightGray
        box.cornerRadius = 16
        box.fillColor = NSColor.black.withAlphaComponent(0.3)
        box.titlePosition = .noTitle
        box.contentViewMargins = .zero
        box.translatesAutoresizingMaskIntoConstraints = true
        box.autoresizingMask = [.width, .height]
        let content = NSView(frame: .zero)
        content.addSubview(box)
        window.contentView = content
    }

    /// Show the overlay at a Cocoa screen rect (same coordinate space as `SnapGeometry.rect`).
    func show(at rect: CGRect) {
        window.setFrame(rect, display: true)
        box.frame = window.contentView?.bounds ?? .zero
        if !window.isVisible { window.orderFront(nil) }
    }

    func hide() {
        if window.isVisible { window.orderOut(nil) }
    }
}
