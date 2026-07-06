import Testing
import CoreGraphics
@testable import SpectacleCore

private let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
private func calc(_ a: WindowAction, _ win: CGRect) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(windowRect: win, sourceVisibleFrame: frame, destinationVisibleFrame: frame))
}

@Test func makeLargerGrowsSymmetrically() {
    // centered 800×600 → +30 each dim, origin shifts −15 each
    #expect(calc(.makeLarger, CGRect(x: 320, y: 150, width: 800, height: 600)) == CGRect(x: 305, y: 135, width: 830, height: 630))
}

@Test func makeSmallerNoOpBelowQuarter() {
    // quarter of 1440×900 = 360×225 minimum; a 360×600 window is already at/under the width min → no-op
    let tiny = CGRect(x: 0, y: 0, width: 360, height: 600)
    #expect(calc(.makeSmaller, tiny) == tiny)
}

@Test func makeLargerClampsToScreen() {
    let almost = CGRect(x: 0, y: 0, width: 1430, height: 890)
    let r = calc(.makeLarger, almost)!
    #expect(r.width == 1440)
    #expect(r.height == 900)
}
