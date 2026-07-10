import Testing
import CoreGraphics
@testable import SpectacleCore

private let vf = CGRect(x: 0, y: 0, width: 1440, height: 900)

@Test func snapLeftHalfNoGap() {
    #expect(SnapGeometry.rect(.leftHalf, visibleFrame: vf, gap: .none)
            == CGRect(x: 0, y: 0, width: 720, height: 900))
}

@Test func snapMaximizeNoGap() {
    #expect(SnapGeometry.rect(.maximize, visibleFrame: vf, gap: .none) == vf)
}

@Test func snapTopLeftQuarterNoGap() {
    // Cocoa top-left quarter: upper-left corner of the screen.
    #expect(SnapGeometry.rect(.topLeft, visibleFrame: vf, gap: .none)
            == CGRect(x: 0, y: 450, width: 720, height: 450))
}

@Test func snapThirdsPartitionTheWidth() {
    let first = SnapGeometry.rect(.firstThird, visibleFrame: vf, gap: .none)
    let center = SnapGeometry.rect(.centerThird, visibleFrame: vf, gap: .none)
    let last = SnapGeometry.rect(.lastThird, visibleFrame: vf, gap: .none)
    #expect(first.minX == 0)
    #expect(center.minX == first.maxX)
    #expect(last.maxX == vf.maxX)
    #expect(first.width == 480 && center.width == 480 && last.width == 480)
}

@Test func snapTwoThirdsSpanTwoColumns() {
    let firstTwo = SnapGeometry.rect(.firstTwoThirds, visibleFrame: vf, gap: .none)
    #expect(firstTwo.minX == 0 && firstTwo.width == 960)
    let lastTwo = SnapGeometry.rect(.lastTwoThirds, visibleFrame: vf, gap: .none)
    #expect(lastTwo.maxX == vf.maxX && lastTwo.width == 960)
}

@Test func snapAppliesGap() {
    // gap 10 → left half becomes the same rect WindowCalculator produces for a fresh left-half.
    let snapped = SnapGeometry.rect(.leftHalf, visibleFrame: vf, gap: WindowGap(size: 10))
    #expect(snapped == CGRect(x: 10, y: 10, width: 705, height: 880))
}

private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)   // Cocoa: minY bottom, maxY top

@Test func zoneNilInInterior() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 700, y: 450), in: screen) == nil)
}
@Test func zoneTopEdge() {
    // near maxY (top), away from corners → .top
    #expect(SnapGeometry.zone(for: CGPoint(x: 700, y: 898), in: screen) == .top)
}
@Test func zoneBottomEdge() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 700, y: 2), in: screen) == .bottom)
}
@Test func zoneLeftEdge() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 2, y: 450), in: screen) == .left)
}
@Test func zoneCornerTopLeftWins() {
    // within 25pt of both the left and the top → corner, not edge
    #expect(SnapGeometry.zone(for: CGPoint(x: 3, y: 890), in: screen) == .topLeft)
}
@Test func zoneCornerBottomRight() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 1438, y: 3), in: screen) == .bottomRight)
}

@Test func sideHalfNearTopCorner() {
    // On the left edge within 145pt of the top → top half; middle → nil (plain left half)
    #expect(SnapGeometry.sideEdgeHalf(cursorY: 850, in: screen) == .topHalf)
    #expect(SnapGeometry.sideEdgeHalf(cursorY: 50, in: screen) == .bottomHalf)
    #expect(SnapGeometry.sideEdgeHalf(cursorY: 450, in: screen) == nil)
}

@Test func bottomEdgeThirdByCursorX() {
    #expect(SnapGeometry.bottomEdgeThird(cursorX: 100, in: screen) == .first)
    #expect(SnapGeometry.bottomEdgeThird(cursorX: 720, in: screen) == .center)
    #expect(SnapGeometry.bottomEdgeThird(cursorX: 1400, in: screen) == .last)
}
