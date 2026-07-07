import Testing
import CoreGraphics
@testable import SpectacleCore

private let F = CGRect(x: 0, y: 0, width: 1440, height: 900)
private func c(_ a: WindowAction, _ w: CGRect) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(windowRect: w, sourceVisibleFrame: F, destinationVisibleFrame: F))
}
private let offCenter = CGRect(x: 0, y: 0, width: 10, height: 10)   // matches no half/corner axis

@Test func rightHalfCycle() {
    let half = CGRect(x: 720, y: 0, width: 720, height: 900)
    #expect(c(.rightHalf, offCenter) == half)
    let twoThird = c(.rightHalf, half)
    #expect(twoThird == CGRect(x: 480, y: 0, width: 960, height: 900))   // ⅔, right-aligned
    let oneThird = c(.rightHalf, twoThird!)
    #expect(oneThird == CGRect(x: 960, y: 0, width: 480, height: 900))   // ⅓, right-aligned
    #expect(c(.rightHalf, oneThird!) == half)
}

@Test func topHalfCycle() {
    let base = CGRect(x: 0, y: 450, width: 1440, height: 450)           // top = larger y (Cocoa)
    #expect(c(.topHalf, offCenter) == base)
    let twoThirds = c(.topHalf, base)
    #expect(twoThirds == CGRect(x: 0, y: 300, width: 1440, height: 600))
    let oneThird = c(.topHalf, twoThirds!)
    #expect(oneThird == CGRect(x: 0, y: 600, width: 1440, height: 300))
    #expect(c(.topHalf, oneThird!) == base)
}

@Test func bottomHalfCycle() {
    let base = CGRect(x: 0, y: 0, width: 1440, height: 450)
    #expect(c(.bottomHalf, offCenter) == base)
    let twoThirds = c(.bottomHalf, base)
    #expect(twoThirds == CGRect(x: 0, y: 0, width: 1440, height: 600))
    let oneThird = c(.bottomHalf, twoThirds!)
    #expect(oneThird == CGRect(x: 0, y: 0, width: 1440, height: 300))
    #expect(c(.bottomHalf, oneThird!) == base)
}

@Test func upperRightCycleWidthOnly() {
    let q = CGRect(x: 720, y: 450, width: 720, height: 450)
    #expect(c(.upperRight, offCenter) == q)
    let t2 = c(.upperRight, q);  #expect(t2 == CGRect(x: 480, y: 450, width: 960, height: 450))
    let t1 = c(.upperRight, t2!); #expect(t1 == CGRect(x: 960, y: 450, width: 480, height: 450))
}

@Test func lowerLeftCycleWidthOnly() {
    let q = CGRect(x: 0, y: 0, width: 720, height: 450)
    #expect(c(.lowerLeft, CGRect(x: 0, y: 890, width: 10, height: 10)) == q)   // off-axis vertically
    let t2 = c(.lowerLeft, q);   #expect(t2 == CGRect(x: 0, y: 0, width: 960, height: 450))
    let t1 = c(.lowerLeft, t2!); #expect(t1 == CGRect(x: 0, y: 0, width: 480, height: 450))
}

@Test func lowerRightCycleWidthOnly() {
    let q = CGRect(x: 720, y: 0, width: 720, height: 450)
    #expect(c(.lowerRight, CGRect(x: 0, y: 890, width: 10, height: 10)) == q)
    let t2 = c(.lowerRight, q);   #expect(t2 == CGRect(x: 480, y: 0, width: 960, height: 450))
    let t1 = c(.lowerRight, t2!); #expect(t1 == CGRect(x: 960, y: 0, width: 480, height: 450))
}

@Test func nextThirdFullSixRegionLoop() {
    var w = CGRect(x: 0, y: 0, width: 480, height: 900)   // left column
    let expected = [
        CGRect(x: 480, y: 0, width: 480, height: 900),    // mid column
        CGRect(x: 960, y: 0, width: 480, height: 900),    // right column
        CGRect(x: 0, y: 600, width: 1440, height: 300),   // top row
        CGRect(x: 0, y: 300, width: 1440, height: 300),   // mid row
        CGRect(x: 0, y: 0, width: 1440, height: 300),     // bottom row
        CGRect(x: 0, y: 0, width: 480, height: 900),      // wraps to left column
    ]
    for e in expected { let n = c(.nextThird, w)!; #expect(n == e); w = n }
}

@Test func previousThirdWrapsBackwardToBottomRow() {
    let leftCol = CGRect(x: 0, y: 0, width: 480, height: 900)
    #expect(c(.previousThird, leftCol) == CGRect(x: 0, y: 0, width: 1440, height: 300))
}
