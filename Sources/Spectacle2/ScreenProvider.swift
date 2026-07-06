import AppKit

/// Maps a window's Cocoa rect to source/destination visible frames for the calculator.
enum ScreenProvider {
    static func screen(containing rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
    }

    static func sourceVisibleFrame(for rect: CGRect) -> CGRect {
        (screen(containing: rect) ?? NSScreen.main)?.visibleFrame ?? .zero
    }

    /// direction: +1 next, -1 previous. Falls back to the source frame with <2 displays.
    static func destinationVisibleFrame(for rect: CGRect, direction: Int) -> CGRect {
        let ordered = NSScreen.screens.sorted {
            ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY)
        }
        guard ordered.count > 1,
              let src = screen(containing: rect),
              let idx = ordered.firstIndex(of: src) else {
            return sourceVisibleFrame(for: rect)
        }
        let count = ordered.count
        let j = ((idx + direction) % count + count) % count
        return ordered[j].visibleFrame
    }
}
