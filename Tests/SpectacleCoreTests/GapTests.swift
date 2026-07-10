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

private func calcGap(_ a: WindowAction, _ win: CGRect, gap: CGFloat, skipTop: Bool = false) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(
        windowRect: win, sourceVisibleFrame: vf, destinationVisibleFrame: vf,
        gap: gap, skipGapTopEdge: skipTop))
}

@Test func gapZeroMatchesUngapped() {
    // Regression guard: gap 0 reproduces the classic left-half exactly.
    #expect(calcGap(.leftHalf, CGRect(x: 200, y: 100, width: 400, height: 300), gap: 0)
            == CGRect(x: 0, y: 0, width: 720, height: 900))
}

@Test func gapLeftHalfHasOuterAndInnerGap() {
    // gap 10 → half=5. Working frame = vf inset 5 = (5,5,1430,890); left half width floor(1430/2)=715
    // at x=5; then inset 5 → (10,10,705,880). Right edge = 715, i.e. 5 short of vf.midX (720).
    let left = calcGap(.leftHalf, CGRect(x: 0, y: 0, width: 100, height: 100), gap: 10)
    #expect(left == CGRect(x: 10, y: 10, width: 705, height: 880))
    // Right half mirrors: left edge 10pt past the midline → 10pt gap between the two halves.
    let right = calcGap(.rightHalf, CGRect(x: 0, y: 0, width: 100, height: 100), gap: 10)
    #expect(right?.minX == 725)          // 715 (working right-half x) + 10 (working inset) ... see note
}

@Test func gapFullscreenLeavesUniformMargin() {
    // gap 20 → full-G (20pt) margin on every edge, so a maximized window sits the same 20pt off
    // the screen as a half-window's outer edge. vf inset by half twice = 10+10 = 20 all round.
    #expect(calcGap(.fullscreen, .zero, gap: 20) == CGRect(x: 20, y: 20, width: 1400, height: 860))
}

@Test func gapDoesNotAffectCenter() {
    // Center preserves size and centers within the TRUE visible frame regardless of gap.
    let win = CGRect(x: 0, y: 0, width: 400, height: 300)
    #expect(calcGap(.center, win, gap: 40) == WindowCalculator.calculate(.center,
        CalculationInput(windowRect: win, sourceVisibleFrame: vf, destinationVisibleFrame: vf)))
}

@Test func gapCyclingStillAdvances() {
    // A gapped left-half, pressed again, must still advance to the (gapped) two-thirds.
    let half = calcGap(.leftHalf, CGRect(x: 0, y: 0, width: 100, height: 100), gap: 10)!
    let twoThird = calcGap(.leftHalf, half, gap: 10)!
    #expect(twoThird.width > half.width)   // advanced, not stuck
}

@Test func gapSkipTopEdgeOnFullscreen() {
    // skipTop → no gap at maxY; other three edges still gapped by 20.
    let r = calcGap(.fullscreen, .zero, gap: 20, skipTop: true)!
    #expect(r.maxY == vf.maxY)
    #expect(r.minX == 20 && r.minY == 20 && r.maxX == 1420)
}
