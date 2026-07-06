import Testing
import CoreGraphics
@testable import SpectacleCore

private let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
private func calc(_ a: WindowAction, _ win: CGRect) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(windowRect: win, sourceVisibleFrame: frame, destinationVisibleFrame: frame))
}

@Test func centerKeepsSize() {
    // (1440-800)/2 = 320 ; (900-600)/2 = 150
    #expect(calc(.center, CGRect(x: 0, y: 0, width: 800, height: 600)) == CGRect(x: 320, y: 150, width: 800, height: 600))
}

@Test func fullscreenIsVisibleFrame() {
    #expect(calc(.fullscreen, CGRect(x: 10, y: 10, width: 50, height: 50)) == frame)
}
