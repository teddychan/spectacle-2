import CoreGraphics

/// A drag-snap landing target. Unlike `WindowCalculator` these never cycle (½→⅔→⅓) — a fresh
/// drag-snap always produces the plain tile — but they honor the configured `WindowGap`.
public enum SnapTarget: Equatable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight   // quarters
    case maximize
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
}

public enum SnapGeometry {
    /// The Cocoa (bottom-left origin) rect for `target` within `visibleFrame`, with `gap` applied.
    public static func rect(_ target: SnapTarget, visibleFrame vf: CGRect, gap: WindowGap) -> CGRect {
        let half = gap.size / 2
        let f = WindowGap.inset(vf, half: half, skipTop: gap.skipTopEdge)   // working frame
        let w2 = floor(f.width / 2), h2 = floor(f.height / 2)
        let topY = f.minY + h2                       // bottom of the upper row (Cocoa)
        let w3 = floor(f.width / 3), w23 = floor(f.width * 2 / 3)
        let plain: CGRect
        switch target {
        case .leftHalf:    plain = CGRect(x: f.minX, y: f.minY, width: w2, height: f.height)
        case .rightHalf:   plain = CGRect(x: f.maxX - w2, y: f.minY, width: w2, height: f.height)
        case .topHalf:     plain = CGRect(x: f.minX, y: topY, width: f.width, height: f.maxY - topY)
        case .bottomHalf:  plain = CGRect(x: f.minX, y: f.minY, width: f.width, height: h2)
        case .topLeft:     plain = CGRect(x: f.minX, y: topY, width: w2, height: f.maxY - topY)
        case .topRight:    plain = CGRect(x: f.maxX - w2, y: topY, width: w2, height: f.maxY - topY)
        case .bottomLeft:  plain = CGRect(x: f.minX, y: f.minY, width: w2, height: h2)
        case .bottomRight: plain = CGRect(x: f.maxX - w2, y: f.minY, width: w2, height: h2)
        case .maximize:    return WindowGap.inset(f, half: half, skipTop: gap.skipTopEdge)
        case .firstThird:  plain = CGRect(x: f.minX, y: f.minY, width: w3, height: f.height)
        case .centerThird: plain = CGRect(x: f.minX + w3, y: f.minY, width: w3, height: f.height)
        case .lastThird:   plain = CGRect(x: f.maxX - w3, y: f.minY, width: w3, height: f.height)
        case .firstTwoThirds: plain = CGRect(x: f.minX, y: f.minY, width: w23, height: f.height)
        case .lastTwoThirds:  plain = CGRect(x: f.maxX - w23, y: f.minY, width: w23, height: f.height)
        }
        return WindowGap.inset(plain, half: half, skipTop: gap.skipTopEdge)
    }
}
