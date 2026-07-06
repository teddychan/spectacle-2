import Testing
import CoreGraphics
@testable import SpectacleCore

@Test func centeredWithinRequiresContainmentAndCenter() {
    let container = CGRect(x: 0, y: 0, width: 720, height: 900)
    #expect(SpectacleGeometry.rectCenteredWithin(container: container, win: container))
    // shifted off-center by more than 1pt → not centered
    let off = CGRect(x: 5, y: 0, width: 720, height: 900)
    #expect(!SpectacleGeometry.rectCenteredWithin(container: container, win: off))
    // larger than container → not contained
    let big = CGRect(x: 0, y: 0, width: 960, height: 900)
    #expect(!SpectacleGeometry.rectCenteredWithin(container: container, win: big))
}

@Test func fitsWithinComparesDimensions() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    #expect(SpectacleGeometry.rectFitsWithin(win: CGRect(x: 0, y: 0, width: 800, height: 600), screen: screen))
    #expect(!SpectacleGeometry.rectFitsWithin(win: CGRect(x: 0, y: 0, width: 1600, height: 600), screen: screen))
}
