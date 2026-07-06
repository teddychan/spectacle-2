import Testing
import CoreGraphics
@testable import SpectacleCore

private let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
private func calc(_ a: WindowAction, _ win: CGRect) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(windowRect: win, sourceVisibleFrame: frame, destinationVisibleFrame: frame))
}

@Test func upperLeftQuarter() {
    // quarter: 720×450, x=0, y = 0 + 450 + (900 % 2 = 0) = 450 (top-left in Cocoa coords)
    #expect(calc(.upperLeft, CGRect(x: 0, y: 0, width: 10, height: 10)) == CGRect(x: 0, y: 450, width: 720, height: 450))
}

@Test func lowerRightQuarter() {
    #expect(calc(.lowerRight, CGRect(x: 0, y: 0, width: 10, height: 10)) == CGRect(x: 720, y: 0, width: 720, height: 450))
}

@Test func upperLeftCyclesWidthOnly() {
    let quarter = CGRect(x: 0, y: 450, width: 720, height: 450)
    let twoThird = calc(.upperLeft, quarter)          // width→960, y/h unchanged
    #expect(twoThird == CGRect(x: 0, y: 450, width: 960, height: 450))
    let oneThird = calc(.upperLeft, twoThird!)         // width→480
    #expect(oneThird == CGRect(x: 0, y: 450, width: 480, height: 450))
}
