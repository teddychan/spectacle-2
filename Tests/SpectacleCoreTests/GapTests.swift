import Testing
import CoreGraphics
@testable import SpectacleCore

private let vf = CGRect(x: 0, y: 0, width: 1440, height: 900)

@Test func gapInsetZeroIsIdentity() {
    #expect(WindowGap.inset(vf, half: 0, skipTop: false) == vf)
}

@Test func gapInsetShrinksAllEdgesByHalf() {
    // half = 5 → 5pt off left, right, top and bottom.
    #expect(WindowGap.inset(vf, half: 5, skipTop: false)
            == CGRect(x: 5, y: 5, width: 1430, height: 890))
}

@Test func gapInsetSkipTopLeavesTopEdge() {
    // Cocoa coords: top edge is maxY. skipTop must not shrink the top → height loses only the
    // bottom 5pt, origin.y rises 5pt, maxY stays at 900.
    let r = WindowGap.inset(vf, half: 5, skipTop: true)
    #expect(r == CGRect(x: 5, y: 5, width: 1430, height: 895))
    #expect(r.maxY == vf.maxY)
}
