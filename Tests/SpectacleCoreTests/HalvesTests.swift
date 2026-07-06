import Testing
import CoreGraphics
@testable import SpectacleCore

private let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
private func calc(_ a: WindowAction, _ win: CGRect) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(windowRect: win, sourceVisibleFrame: frame, destinationVisibleFrame: frame))
}

@Test func leftHalfBase() {
    #expect(calc(.leftHalf, CGRect(x: 200, y: 100, width: 400, height: 300)) == CGRect(x: 0, y: 0, width: 720, height: 900))
}

@Test func leftHalfCyclesHalfTwoThirdOneThird() {
    let half = CGRect(x: 0, y: 0, width: 720, height: 900)
    let twoThird = calc(.leftHalf, half)
    #expect(twoThird == CGRect(x: 0, y: 0, width: 960, height: 900))
    let oneThird = calc(.leftHalf, twoThird!)
    #expect(oneThird == CGRect(x: 0, y: 0, width: 480, height: 900))
    let backToHalf = calc(.leftHalf, oneThird!)
    #expect(backToHalf == half)
}

@Test func rightHalfBaseAndCycle() {
    #expect(calc(.rightHalf, CGRect(x: 0, y: 0, width: 10, height: 10)) == CGRect(x: 720, y: 0, width: 720, height: 900))
    let half = CGRect(x: 720, y: 0, width: 720, height: 900)
    #expect(calc(.rightHalf, half) == CGRect(x: 480, y: 0, width: 960, height: 900)) // ⅔ right-aligned
}

@Test func topAndBottomHalfBase() {
    // top uses larger y (Cocoa bottom-left): y = 0 + 450 + (900 % 2 == 0) = 450
    #expect(calc(.topHalf, CGRect(x: 0, y: 0, width: 10, height: 10)) == CGRect(x: 0, y: 450, width: 1440, height: 450))
    #expect(calc(.bottomHalf, CGRect(x: 0, y: 0, width: 10, height: 10)) == CGRect(x: 0, y: 0, width: 1440, height: 450))
}
