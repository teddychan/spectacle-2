import Testing
import CoreGraphics
@testable import SpectacleCore

private let source = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let dest = CGRect(x: 1440, y: 0, width: 1000, height: 800)

private func moveToDisplay(_ win: CGRect) -> CGRect? {
    WindowCalculator.calculate(.nextDisplay, CalculationInput(windowRect: win, sourceVisibleFrame: source, destinationVisibleFrame: dest))
}

@Test func fitsOnDestinationSoCentered() {
    // 400×300 fits in 1000×800 → centered on dest: x = 1440 + (1000-400)/2 = 1740 ; y = (800-300)/2 = 250
    #expect(moveToDisplay(CGRect(x: 10, y: 10, width: 400, height: 300)) == CGRect(x: 1740, y: 250, width: 400, height: 300))
}

@Test func tooBigSoFillsDestination() {
    #expect(moveToDisplay(CGRect(x: 0, y: 0, width: 1400, height: 900)) == dest)
}
