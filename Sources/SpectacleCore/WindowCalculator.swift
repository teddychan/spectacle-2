import Foundation
import CoreGraphics

public struct CalculationInput: Equatable, Sendable {
    public var windowRect: CGRect
    public var sourceVisibleFrame: CGRect
    public var destinationVisibleFrame: CGRect
    public init(windowRect: CGRect, sourceVisibleFrame: CGRect, destinationVisibleFrame: CGRect) {
        self.windowRect = windowRect
        self.sourceVisibleFrame = sourceVisibleFrame
        self.destinationVisibleFrame = destinationVisibleFrame
    }
}

/// Pure window-position math, a 1:1 port of Spectacle's JavaScriptCore calculations.
/// Returns the new window rect, or nil for a no-op (or a non-geometry action).
public enum WindowCalculator {
    public static func calculate(_ action: WindowAction, _ input: CalculationInput) -> CGRect? {
        let win = input.windowRect
        let frame = input.destinationVisibleFrame
        switch action {
        case .leftHalf:   return leftHalf(win, frame)
        case .rightHalf:  return rightHalf(win, frame)
        case .topHalf:    return topHalf(win, frame)
        case .bottomHalf: return bottomHalf(win, frame)
        case .upperLeft:  return upperLeft(win, frame)
        case .upperRight: return upperRight(win, frame)
        case .lowerLeft:  return lowerLeft(win, frame)
        case .lowerRight: return lowerRight(win, frame)
        case .center:     return center(win, frame)
        case .fullscreen: return frame
        default:          return nil   // filled in by later tasks
        }
    }

    // MARK: Halves

    static func leftHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.width = floor(f.width / 2.0)          // left-aligned at f.x
        guard abs(win.midY - base.midY) <= 1.0 else { return base }
        var twoThird = base; twoThird.size.width = floor(f.width * 2.0 / 3.0)
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) {
            var oneThird = base; oneThird.size.width = floor(f.width / 3.0); return oneThird
        }
        return base
    }

    static func rightHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.width = floor(f.width / 2.0)
        base.origin.x += base.width
        guard abs(win.midY - base.midY) <= 1.0 else { return base }
        var twoThird = base
        twoThird.size.width = floor(f.width * 2.0 / 3.0)
        twoThird.origin.x = f.maxX - twoThird.width
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) {
            var oneThird = base
            oneThird.size.width = floor(f.width / 3.0)
            oneThird.origin.x = f.maxX - oneThird.width
            return oneThird
        }
        return base
    }

    static func topHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.height = floor(f.height / 2.0)
        base.origin.y += base.height + f.height.truncatingRemainder(dividingBy: 2.0)
        guard abs(win.midX - base.midX) <= 1.0 else { return base }
        var twoThirds = base
        twoThirds.size.height = floor(f.height * 2.0 / 3.0)
        twoThirds.origin.y = f.maxY - twoThirds.height
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThirds }
        if SpectacleGeometry.rectCenteredWithin(container: twoThirds, win: win) {
            var oneThird = base
            oneThird.size.height = floor(f.height / 3.0)
            oneThird.origin.y = f.maxY - oneThird.height
            return oneThird
        }
        return base
    }

    static func bottomHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.height = floor(f.height / 2.0)          // bottom-aligned at f.y
        guard abs(win.midX - base.midX) <= 1.0 else { return base }
        var twoThirds = base; twoThirds.size.height = floor(f.height * 2.0 / 3.0)
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThirds }
        if SpectacleGeometry.rectCenteredWithin(container: twoThirds, win: win) {
            var oneThird = base; oneThird.size.height = floor(f.height / 3.0); return oneThird
        }
        return base
    }

    // MARK: Corners

    private static func topY(_ f: CGRect) -> CGFloat {
        f.origin.y + floor(f.height / 2.0) + f.height.truncatingRemainder(dividingBy: 2.0)
    }

    static func upperLeft(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        q.origin.y = topY(f)
        return cornerCycle(win, f, quarter: q, rightAligned: false)
    }
    static func upperRight(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        q.origin.x += q.width; q.origin.y = topY(f)
        return cornerCycle(win, f, quarter: q, rightAligned: true)
    }
    static func lowerLeft(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        return cornerCycle(win, f, quarter: q, rightAligned: false)
    }
    static func lowerRight(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        q.origin.x += q.width
        return cornerCycle(win, f, quarter: q, rightAligned: true)
    }

    /// Shared quarter → ⅔-width → ⅓-width cycle (height and vertical edge fixed).
    private static func cornerCycle(_ win: CGRect, _ f: CGRect, quarter q: CGRect, rightAligned: Bool) -> CGRect {
        guard abs(win.midY - q.midY) <= 1.0 else { return q }
        func widthVariant(_ w: CGFloat) -> CGRect {
            var r = q; r.size.width = w
            if rightAligned { r.origin.x = f.maxX - w }
            return r
        }
        let twoThird = widthVariant(floor(f.width * 2.0 / 3.0))
        if SpectacleGeometry.rectCenteredWithin(container: q, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) {
            return widthVariant(floor(f.width / 3.0))
        }
        return q
    }

    // MARK: Center

    static func center(_ win: CGRect, _ f: CGRect) -> CGRect {
        var r = win
        r.origin.x = ((f.width - win.width) / 2.0).rounded() + f.origin.x
        r.origin.y = ((f.height - win.height) / 2.0).rounded() + f.origin.y
        return r
    }
}
