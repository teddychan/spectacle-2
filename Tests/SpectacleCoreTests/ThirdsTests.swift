import Testing
import CoreGraphics
@testable import SpectacleCore

private let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)   // ⅓ w = 480, ⅓ h = 300
private func calc(_ a: WindowAction, _ win: CGRect) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(windowRect: win, sourceVisibleFrame: frame, destinationVisibleFrame: frame))
}

@Test func uncenteredDefaultsToLeftColumn() {
    #expect(calc(.nextThird, CGRect(x: 5, y: 5, width: 100, height: 100)) == CGRect(x: 0, y: 0, width: 480, height: 900))
}

@Test func nextThirdCyclesColumnsThenRows() {
    let leftCol = CGRect(x: 0, y: 0, width: 480, height: 900)
    let midCol = calc(.nextThird, leftCol)
    #expect(midCol == CGRect(x: 480, y: 0, width: 480, height: 900))
    let rightCol = calc(.nextThird, midCol!)
    #expect(rightCol == CGRect(x: 960, y: 0, width: 480, height: 900))
    let topRow = calc(.nextThird, rightCol!)   // regions[3]: top row, y = 900 - 300 = 600
    #expect(topRow == CGRect(x: 0, y: 600, width: 1440, height: 300))
}

@Test func previousThirdWrapsBackward() {
    let leftCol = CGRect(x: 0, y: 0, width: 480, height: 900)
    // previous of regions[0] wraps to regions[5] = bottom row (y = 900 - 300*3 = 0)
    #expect(calc(.previousThird, leftCol) == CGRect(x: 0, y: 0, width: 1440, height: 300))
}
