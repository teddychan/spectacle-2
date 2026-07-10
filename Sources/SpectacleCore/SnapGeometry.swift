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

    public enum SnapZone: Equatable, Sendable {
        case top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight
    }
    public enum ThirdColumn: Equatable, Sendable { case first, center, last }

    /// Rectangle default zone geometry (points).
    public static let edgeMargin: CGFloat = 5
    public static let cornerSize: CGFloat = 20        // → 25pt corner band with the 5pt margin
    public static let shortEdgeSize: CGFloat = 145

    /// The zone the cursor is in for a screen (Cocoa coords), or nil if in the interior.
    /// Corners take priority over edges.
    public static func zone(for c: CGPoint, in s: CGRect) -> SnapZone? {
        guard s.contains(c) else { return nil }
        let band = edgeMargin + cornerSize                    // 25
        let nearLeft = c.x < s.minX + band
        let nearRight = c.x > s.maxX - band
        let nearTop = c.y > s.maxY - band                     // Cocoa: top = maxY
        let nearBottom = c.y < s.minY + band
        if nearLeft && nearTop { return .topLeft }
        if nearRight && nearTop { return .topRight }
        if nearLeft && nearBottom { return .bottomLeft }
        if nearRight && nearBottom { return .bottomRight }
        if c.x < s.minX + edgeMargin { return .left }
        if c.x > s.maxX - edgeMargin { return .right }
        if c.y > s.maxY - edgeMargin { return .top }
        if c.y < s.minY + edgeMargin { return .bottom }
        return nil
    }

    /// On a left/right edge: within `shortEdgeSize` of the top → top half, of the bottom → bottom
    /// half, else nil (→ plain side half). Cocoa coords.
    public static func sideEdgeHalf(cursorY y: CGFloat, in s: CGRect) -> SnapTarget? {
        if y >= s.maxY - shortEdgeSize { return .topHalf }
        if y <= s.minY + shortEdgeSize { return .bottomHalf }
        return nil
    }

    /// Which horizontal third the cursor's x falls in.
    public static func bottomEdgeThird(cursorX x: CGFloat, in s: CGRect) -> ThirdColumn {
        let third = s.width / 3
        if x <= s.minX + third { return .first }
        if x >= s.maxX - third { return .last }
        return .center
    }
}
