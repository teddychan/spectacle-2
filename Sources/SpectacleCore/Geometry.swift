import Foundation
import CoreGraphics

/// Pure geometry predicates ported from Spectacle's `SpectacleWindowCalculationHelpers.js`.
public enum SpectacleGeometry {
    /// `win` is contained in `container` and their centers coincide within 1pt on both axes.
    public static func rectCenteredWithin(container: CGRect, win: CGRect) -> Bool {
        let centeredX = abs(container.midX - win.midX) <= 1.0
        let centeredY = abs(container.midY - win.midY) <= 1.0
        return container.contains(win) && centeredX && centeredY
    }

    public static func rectFitsWithin(win: CGRect, screen: CGRect) -> Bool {
        win.width <= screen.width && win.height <= screen.height
    }
}
