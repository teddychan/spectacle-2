import Testing
import CoreGraphics
@testable import SpectacleCore

private let F = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let F2 = CGRect(x: 100, y: 50, width: 1200, height: 800)   // offset-origin screen
private func c(_ a: WindowAction, _ w: CGRect, _ frame: CGRect) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(windowRect: w, sourceVisibleFrame: frame, destinationVisibleFrame: frame))
}

@Test func offsetOriginLeftHalf() {
    // base honours the frame origin: width floor(1200/2)=600 at x=100
    #expect(c(.leftHalf, CGRect(x: 0, y: 0, width: 10, height: 10), F2) == CGRect(x: 100, y: 50, width: 600, height: 800))
}

@Test func offsetOriginCenterAndFullscreen() {
    // x = round((1200-200)/2)+100 = 600 ; y = round((800-100)/2)+50 = 400
    #expect(c(.center, CGRect(x: 0, y: 0, width: 200, height: 100), F2) == CGRect(x: 600, y: 400, width: 200, height: 100))
    #expect(c(.fullscreen, CGRect(x: 0, y: 0, width: 10, height: 10), F2) == F2)
}

@Test func makeLargerRetainsEdgeSnap() {
    // full-width, bottom-anchored window: grows in height only, staying flush to bottom + sides
    #expect(c(.makeLarger, CGRect(x: 0, y: 0, width: 1440, height: 400), F) == CGRect(x: 0, y: 0, width: 1440, height: 430))
}

@Test func makeSmallerFromFullscreenShrinksSymmetrically() {
    // against all four edges + shrinking → symmetric inset by 15pt each side
    #expect(c(.makeSmaller, F, F) == CGRect(x: 15, y: 15, width: 1410, height: 870))
}
