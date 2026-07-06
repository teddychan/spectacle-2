# Spectacle 2 Window-Action Engine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Spectacle 2's keyboard-driven window mover/resizer — 18 actions with full Spectacle parity, user-configurable global shortcuts, undo/redo — on the existing DragonKit shell.

**Architecture:** A pure `SpectacleCore` library (geometry, history, shortcut model; Foundation/CoreGraphics only) that is unit-tested exhaustively, plus thin `Spectacle2` app adapters (Accessibility, screens, Carbon hotkeys, orchestrator) and a Shortcuts settings pane. The single AX↔Cocoa coordinate flip lives in the app; the core is coordinate-agnostic (Cocoa bottom-left).

**Tech Stack:** Swift 6.1 (Xcode 26), SwiftPM, swift-testing (`import Testing`), Accessibility API, Carbon `RegisterEventHotKey`, DragonKit + DragonKitUpdates.

**Spec:** `docs/superpowers/specs/2026-07-06-spectacle-window-engine-design.md`. Original geometry (ported here) lives in git history: `git show master:"Spectacle/Resources/Window Position Calculations/<file>.js"`.

**Conventions:** All geometry math in Cocoa bottom-left coordinates. Test fixtures use `frame = CGRect(x: 0, y: 0, width: 1440, height: 900)` unless noted. Commit after every green step. `swift test` runs the core tests; `swift build` must stay green throughout.

---

## Task 1: Add SpectacleCore library + test target

**Files:**
- Modify: `Package.swift`
- Create: `Sources/SpectacleCore/Placeholder.swift`
- Create: `Tests/SpectacleCoreTests/PackageSmokeTests.swift`

- [ ] **Step 1: Rewrite `Package.swift` to add the library + test targets**

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Spectacle2",
    defaultLocalization: "en",
    platforms: [.macOS("26")],
    dependencies: [
        .package(url: "https://github.com/teddychan/dragon-kit", from: "1.2.1"),
    ],
    targets: [
        .target(name: "SpectacleCore"),
        .executableTarget(
            name: "Spectacle2",
            dependencies: [
                "SpectacleCore",
                .product(name: "DragonKit", package: "dragon-kit"),
                .product(name: "DragonKitUpdates", package: "dragon-kit"),
            ],
            resources: [.process("Resources")],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path/../Frameworks"])
            ]
        ),
        .testTarget(name: "SpectacleCoreTests", dependencies: ["SpectacleCore"]),
    ]
)
```

- [ ] **Step 2: Create a temporary placeholder so the empty target compiles**

`Sources/SpectacleCore/Placeholder.swift`:
```swift
// Deleted in Task 2 once real types exist.
enum SpectacleCorePlaceholder {}
```

- [ ] **Step 3: Write a smoke test**

`Tests/SpectacleCoreTests/PackageSmokeTests.swift`:
```swift
import Testing
@testable import SpectacleCore

@Test func packageBuilds() {
    #expect(Bool(true))
}
```

- [ ] **Step 4: Build + test**

Run: `swift build && swift test`
Expected: Build complete; 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Package.resolved Sources/SpectacleCore Tests/SpectacleCoreTests
git commit -m "Add SpectacleCore library and test target"
```

---

## Task 2: WindowAction enum

**Files:**
- Create: `Sources/SpectacleCore/WindowAction.swift`
- Delete: `Sources/SpectacleCore/Placeholder.swift`
- Test: `Tests/SpectacleCoreTests/WindowActionTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/SpectacleCoreTests/WindowActionTests.swift`:
```swift
import Testing
@testable import SpectacleCore

@Test func hasEighteenActions() {
    #expect(WindowAction.allCases.count == 18)
}

@Test func geometryActionsExcludeHistory() {
    #expect(!WindowAction.geometryActions.contains(.undo))
    #expect(!WindowAction.geometryActions.contains(.redo))
    #expect(WindowAction.geometryActions.count == 16)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter WindowActionTests`
Expected: FAIL (`WindowAction` undefined).

- [ ] **Step 3: Implement**

Delete `Sources/SpectacleCore/Placeholder.swift`. Create `Sources/SpectacleCore/WindowAction.swift`:
```swift
public enum WindowAction: String, CaseIterable, Codable, Sendable {
    case center, fullscreen
    case leftHalf, rightHalf, topHalf, bottomHalf
    case upperLeft, upperRight, lowerLeft, lowerRight
    case nextThird, previousThird
    case nextDisplay, previousDisplay
    case makeLarger, makeSmaller
    case undo, redo

    /// Actions computed by `WindowCalculator` (everything except undo/redo).
    public static var geometryActions: [WindowAction] {
        allCases.filter { $0 != .undo && $0 != .redo }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter WindowActionTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add WindowAction enum (18 actions)"
```

---

## Task 3: Geometry helpers

**Files:**
- Create: `Sources/SpectacleCore/Geometry.swift`
- Test: `Tests/SpectacleCoreTests/GeometryTests.swift`

CGRect already provides `midX`, `midY`, `maxX`, `maxY`, and `contains(_ rect:)`. We add the two Spectacle predicates and a floored-copy helper.

- [ ] **Step 1: Write the failing test**

`Tests/SpectacleCoreTests/GeometryTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter GeometryTests`
Expected: FAIL (`SpectacleGeometry` undefined).

- [ ] **Step 3: Implement**

`Sources/SpectacleCore/Geometry.swift`:
```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter GeometryTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add SpectacleGeometry helpers"
```

---

## Task 4: WindowCalculator — input type + halves

**Files:**
- Create: `Sources/SpectacleCore/WindowCalculator.swift`
- Test: `Tests/SpectacleCoreTests/HalvesTests.swift`

`CalculationInput` and the calculator entry point are introduced here; later tasks extend the `switch`.

- [ ] **Step 1: Write the failing test**

`Tests/SpectacleCoreTests/HalvesTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter HalvesTests`
Expected: FAIL (`WindowCalculator` / `CalculationInput` undefined).

- [ ] **Step 3: Implement**

`Sources/SpectacleCore/WindowCalculator.swift`:
```swift
import Foundation
import CoreGraphics

public struct CalculationInput: Equatable, Sendable {
    public var windowRect: CGRect
    public var sourceVisibleFrame: CGRect
    public var destinationVisibleFrame: CGRect
    public init(windowRect: CGRect, sourceVisibleFrame: CGRect, destinationVisibleFrame: CGRect) {
        self.windowRect = windowRect
        self.sourceVisibleFrame = sourceVisibleFrame
        self.destinationVisibleFrame = destinationVisibleFrame
    }
}

/// Pure window-position math, a 1:1 port of Spectacle's JavaScriptCore calculations.
/// Returns the new window rect, or nil for a no-op (or a non-geometry action).
public enum WindowCalculator {
    public static func calculate(_ action: WindowAction, _ input: CalculationInput) -> CGRect? {
        let win = input.windowRect
        let frame = input.destinationVisibleFrame
        switch action {
        case .leftHalf:   return leftHalf(win, frame)
        case .rightHalf:  return rightHalf(win, frame)
        case .topHalf:    return topHalf(win, frame)
        case .bottomHalf: return bottomHalf(win, frame)
        default:          return nil   // filled in by later tasks
        }
    }

    // MARK: Halves

    static func leftHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.width = floor(f.width / 2.0)          // left-aligned at f.x
        guard abs(win.midY - base.midY) <= 1.0 else { return base }
        var twoThird = base; twoThird.size.width = floor(f.width * 2.0 / 3.0)
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) {
            var oneThird = base; oneThird.size.width = floor(f.width / 3.0); return oneThird
        }
        return base
    }

    static func rightHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.width = floor(f.width / 2.0)
        base.origin.x += base.width
        guard abs(win.midY - base.midY) <= 1.0 else { return base }
        var twoThird = base
        twoThird.size.width = floor(f.width * 2.0 / 3.0)
        twoThird.origin.x = f.maxX - twoThird.width
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) {
            var oneThird = base
            oneThird.size.width = floor(f.width / 3.0)
            oneThird.origin.x = f.maxX - oneThird.width
            return oneThird
        }
        return base
    }

    static func topHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.height = floor(f.height / 2.0)
        base.origin.y += base.height + f.height.truncatingRemainder(dividingBy: 2.0)
        guard abs(win.midX - base.midX) <= 1.0 else { return base }
        var twoThirds = base
        twoThirds.size.height = floor(f.height * 2.0 / 3.0)
        twoThirds.origin.y = f.maxY - twoThirds.height
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThirds }
        if SpectacleGeometry.rectCenteredWithin(container: twoThirds, win: win) {
            var oneThird = base
            oneThird.size.height = floor(f.height / 3.0)
            oneThird.origin.y = f.maxY - oneThird.height
            return oneThird
        }
        return base
    }

    static func bottomHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.height = floor(f.height / 2.0)          // bottom-aligned at f.y
        guard abs(win.midX - base.midX) <= 1.0 else { return base }
        var twoThirds = base; twoThirds.size.height = floor(f.height * 2.0 / 3.0)
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThirds }
        if SpectacleGeometry.rectCenteredWithin(container: twoThirds, win: win) {
            var oneThird = base; oneThird.size.height = floor(f.height / 3.0); return oneThird
        }
        return base
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter HalvesTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add WindowCalculator with halves (½→⅔→⅓ cycling)"
```

---

## Task 5: Corners

**Files:**
- Modify: `Sources/SpectacleCore/WindowCalculator.swift`
- Test: `Tests/SpectacleCoreTests/CornersTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/SpectacleCoreTests/CornersTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CornersTests`
Expected: FAIL (corners return nil → `== ` comparison fails / unwrap nil).

- [ ] **Step 3: Implement — add corner cases to the switch and the four functions**

In `calculate`, replace the `default` with corner cases before it:
```swift
        case .upperLeft:  return upperLeft(win, frame)
        case .upperRight: return upperRight(win, frame)
        case .lowerLeft:  return lowerLeft(win, frame)
        case .lowerRight: return lowerRight(win, frame)
```

Append these to `WindowCalculator`:
```swift
    // MARK: Corners

    private static func topY(_ f: CGRect) -> CGFloat {
        f.origin.y + floor(f.height / 2.0) + f.height.truncatingRemainder(dividingBy: 2.0)
    }

    static func upperLeft(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        q.origin.y = topY(f)
        return cornerCycle(win, f, quarter: q, rightAligned: false)
    }
    static func upperRight(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        q.origin.x += q.width; q.origin.y = topY(f)
        return cornerCycle(win, f, quarter: q, rightAligned: true)
    }
    static func lowerLeft(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        return cornerCycle(win, f, quarter: q, rightAligned: false)
    }
    static func lowerRight(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        q.origin.x += q.width
        return cornerCycle(win, f, quarter: q, rightAligned: true)
    }

    /// Shared quarter → ⅔-width → ⅓-width cycle (height and vertical edge fixed).
    private static func cornerCycle(_ win: CGRect, _ f: CGRect, quarter q: CGRect, rightAligned: Bool) -> CGRect {
        guard abs(win.midY - q.midY) <= 1.0 else { return q }
        func widthVariant(_ w: CGFloat) -> CGRect {
            var r = q; r.size.width = w
            if rightAligned { r.origin.x = f.maxX - w }
            return r
        }
        let twoThird = widthVariant(floor(f.width * 2.0 / 3.0))
        if SpectacleGeometry.rectCenteredWithin(container: q, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) {
            return widthVariant(floor(f.width / 3.0))
        }
        return q
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CornersTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add corner calculations (quarter + width cycle)"
```

---

## Task 6: Center & Fullscreen

**Files:**
- Modify: `Sources/SpectacleCore/WindowCalculator.swift`
- Test: `Tests/SpectacleCoreTests/CenterFullscreenTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/SpectacleCoreTests/CenterFullscreenTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CenterFullscreenTests`
Expected: FAIL.

- [ ] **Step 3: Implement — add cases + functions**

Add to the switch:
```swift
        case .center:     return center(win, frame)
        case .fullscreen: return frame
```
Append:
```swift
    // MARK: Center

    static func center(_ win: CGRect, _ f: CGRect) -> CGRect {
        var r = win
        r.origin.x = ((f.width - win.width) / 2.0).rounded() + f.origin.x
        r.origin.y = ((f.height - win.height) / 2.0).rounded() + f.origin.y
        return r
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CenterFullscreenTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add center and fullscreen calculations"
```

---

## Task 7: Make Larger / Smaller (WindowSizeAdjuster)

**Files:**
- Create: `Sources/SpectacleCore/WindowSizeAdjuster.swift`
- Modify: `Sources/SpectacleCore/WindowCalculator.swift`
- Test: `Tests/SpectacleCoreTests/SizeAdjusterTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/SpectacleCoreTests/SizeAdjusterTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SizeAdjusterTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

`Sources/SpectacleCore/WindowSizeAdjuster.swift` (port of `SpectacleWindowSizeAdjuster.js`):
```swift
import Foundation
import CoreGraphics

enum WindowSizeAdjuster {
    static func resize(_ windowRect: CGRect, _ frame: CGRect, offset: CGFloat) -> CGRect {
        var r = windowRect
        r.size.width += offset
        r.origin.x -= floor(offset / 2.0)
        r = adjustLeftRight(original: windowRect, resized: r, frame: frame)
        if r.width >= frame.width { r.size.width = frame.width }
        r.size.height += offset
        r.origin.y -= floor(offset / 2.0)
        r = adjustTopBottom(original: windowRect, resized: r, frame: frame)
        if r.height >= frame.height { r.size.height = frame.height; r.origin.y = windowRect.origin.y }
        if againstAllEdges(windowRect, frame), offset < 0 {
            r.size.width = windowRect.width + offset
            r.origin.x = windowRect.origin.x - floor(offset / 2.0)
            r.size.height = windowRect.height + offset
            r.origin.y = windowRect.origin.y - floor(offset / 2.0)
        }
        if isTooSmall(r, frame) { return windowRect }
        return r
    }

    private static func againstEdge(_ gap: CGFloat) -> Bool { abs(gap) <= 5.0 }
    private static func againstLeft(_ w: CGRect, _ f: CGRect) -> Bool { againstEdge(w.minX - f.minX) }
    private static func againstRight(_ w: CGRect, _ f: CGRect) -> Bool { againstEdge(w.maxX - f.maxX) }
    private static func againstTop(_ w: CGRect, _ f: CGRect) -> Bool { againstEdge(w.maxY - f.maxY) }
    private static func againstBottom(_ w: CGRect, _ f: CGRect) -> Bool { againstEdge(w.minY - f.minY) }
    private static func againstAllEdges(_ w: CGRect, _ f: CGRect) -> Bool {
        againstLeft(w, f) && againstRight(w, f) && againstTop(w, f) && againstBottom(w, f)
    }

    private static func adjustLeftRight(original: CGRect, resized: CGRect, frame: CGRect) -> CGRect {
        var a = resized
        if againstRight(original, frame) {
            a.origin.x = frame.maxX - a.width
            if againstLeft(original, frame) { a.size.width = frame.width }
        }
        if againstLeft(original, frame) { a.origin.x = frame.minX }
        return a
    }
    private static func adjustTopBottom(original: CGRect, resized: CGRect, frame: CGRect) -> CGRect {
        var a = resized
        if againstTop(original, frame) {
            a.origin.y = frame.maxY - a.height
            if againstBottom(original, frame) { a.size.height = frame.height }
        }
        if againstBottom(original, frame) { a.origin.y = frame.minY }
        return a
    }
    private static func isTooSmall(_ w: CGRect, _ f: CGRect) -> Bool {
        w.width <= floor(f.width / 4.0) || w.height <= floor(f.height / 4.0)
    }
}
```
Add to `calculate`:
```swift
        case .makeLarger: return WindowSizeAdjuster.resize(win, frame, offset: 30)
        case .makeSmaller: return WindowSizeAdjuster.resize(win, frame, offset: -30)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SizeAdjusterTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add make-larger/smaller size adjuster"
```

---

## Task 8: Thirds (next / previous)

**Files:**
- Modify: `Sources/SpectacleCore/WindowCalculator.swift`
- Test: `Tests/SpectacleCoreTests/ThirdsTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/SpectacleCoreTests/ThirdsTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ThirdsTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

Add to `calculate`:
```swift
        case .nextThird:     return third(win, frame, step: +1)
        case .previousThird: return third(win, frame, step: -1)
```
Append to `WindowCalculator`:
```swift
    // MARK: Thirds — 3 vertical columns then 3 horizontal rows

    static func thirds(_ f: CGRect) -> [CGRect] {
        var regions: [CGRect] = []
        let w = floor(f.width / 3.0)
        for i in 0..<3 {
            var r = f; r.origin.x = f.origin.x + w * CGFloat(i); r.size.width = w; regions.append(r)
        }
        let h = floor(f.height / 3.0)
        for i in 0..<3 {
            var r = f
            r.origin.y = f.origin.y + f.height - h * CGFloat(i + 1)
            r.size.height = h
            regions.append(r)
        }
        return regions
    }

    static func third(_ win: CGRect, _ f: CGRect, step: Int) -> CGRect {
        let regions = thirds(f)
        for (i, region) in regions.enumerated() where SpectacleGeometry.rectCenteredWithin(container: region, win: win) {
            let j = ((i + step) % regions.count + regions.count) % regions.count
            return regions[j]
        }
        return regions[0]
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ThirdsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add next/previous third cycling"
```

---

## Task 9: Displays (next / previous)

**Files:**
- Modify: `Sources/SpectacleCore/WindowCalculator.swift`
- Test: `Tests/SpectacleCoreTests/DisplayTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/SpectacleCoreTests/DisplayTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DisplayTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

Add to `calculate` (both use the same fit-or-fill against the destination):
```swift
        case .nextDisplay, .previousDisplay:
            return SpectacleGeometry.rectFitsWithin(win: win, screen: frame) ? center(win, frame) : frame
```
Remove the now-unreachable `default` only if all geometry cases are covered; keep `case .undo, .redo: return nil` explicitly:
```swift
        case .undo, .redo: return nil
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DisplayTests`
Expected: PASS. Then run the whole suite: `swift test` → all green.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add next/previous display move (fit-or-fill)"
```

---

## Task 10: WindowHistory (undo/redo)

**Files:**
- Create: `Sources/SpectacleCore/WindowHistory.swift`
- Test: `Tests/SpectacleCoreTests/WindowHistoryTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/SpectacleCoreTests/WindowHistoryTests.swift`:
```swift
import Testing
import CoreGraphics
@testable import SpectacleCore

private let a = CGRect(x: 0, y: 0, width: 100, height: 100)
private let b = CGRect(x: 10, y: 10, width: 100, height: 100)
private let c = CGRect(x: 20, y: 20, width: 100, height: 100)

@Test func undoRestoresPreviousAndRedoReapplies() {
    var h = WindowHistory()
    let id = 1
    h.record(a, for: id)          // move a→b
    h.record(b, for: id)          // move b→c ; window now at c
    #expect(h.undo(current: c, for: id) == b)
    #expect(h.undo(current: b, for: id) == a)
    #expect(h.undo(current: a, for: id) == nil)   // empty
    #expect(h.redo(current: a, for: id) == b)
    #expect(h.redo(current: b, for: id) == c)
    #expect(h.redo(current: c, for: id) == nil)
}

@Test func recordClearsRedo() {
    var h = WindowHistory()
    let id = 1
    h.record(a, for: id)
    _ = h.undo(current: b, for: id)   // redo stack now has b
    h.record(a, for: id)              // a new move must clear redo
    #expect(h.redo(current: a, for: id) == nil)
}

@Test func historyIsPerWindow() {
    var h = WindowHistory()
    h.record(a, for: 1)
    #expect(h.undo(current: b, for: 2) == nil)   // different window, empty
    #expect(h.undo(current: b, for: 1) == a)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter WindowHistoryTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

`Sources/SpectacleCore/WindowHistory.swift`:
```swift
import CoreGraphics

/// Per-window undo/redo of prior frames. `WindowID` is any Hashable the app supplies.
public struct WindowHistory: Sendable {
    private var undoStacks: [AnyHashable: [CGRect]] = [:]
    private var redoStacks: [AnyHashable: [CGRect]] = [:]

    public init() {}

    /// Called only for geometry moves: pushes the pre-move frame and clears redo.
    public mutating func record<ID: Hashable>(_ frame: CGRect, for id: ID) {
        undoStacks[AnyHashable(id), default: []].append(frame)
        redoStacks[AnyHashable(id)] = []
    }

    public mutating func undo<ID: Hashable>(current: CGRect, for id: ID) -> CGRect? {
        let key = AnyHashable(id)
        guard var stack = undoStacks[key], let previous = stack.popLast() else { return nil }
        undoStacks[key] = stack
        redoStacks[key, default: []].append(current)
        return previous
    }

    public mutating func redo<ID: Hashable>(current: CGRect, for id: ID) -> CGRect? {
        let key = AnyHashable(id)
        guard var stack = redoStacks[key], let next = stack.popLast() else { return nil }
        redoStacks[key] = stack
        undoStacks[key, default: []].append(current)
        return next
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter WindowHistoryTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add WindowHistory undo/redo"
```

---

## Task 11: ModifierFlags + Shortcut model

**Files:**
- Create: `Sources/SpectacleCore/Shortcut.swift`
- Test: `Tests/SpectacleCoreTests/ShortcutTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/SpectacleCoreTests/ShortcutTests.swift`:
```swift
import Testing
@testable import SpectacleCore

@Test func displayStringOrdersModifiersThenKey() {
    // ⌥⌘C : option+command, keyCode 8 (C)
    let s = Shortcut(keyCode: 8, modifiers: [.option, .command])
    #expect(s.displayString == "⌥⌘C")
}

@Test func arrowKeyDisplay() {
    let left = Shortcut(keyCode: 123, modifiers: [.option, .command])
    #expect(left.displayString == "⌥⌘←")
}

@Test func modifierFlagsCodableRoundTrip() throws {
    let flags: ModifierFlags = [.control, .shift, .command]
    let data = try JSONEncoder().encode(flags)
    #expect(try JSONDecoder().decode(ModifierFlags.self, from: data) == flags)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ShortcutTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

`Sources/SpectacleCore/Shortcut.swift`:
```swift
import Foundation

/// Neutral modifier set — no Carbon/AppKit. The app translates to Carbon masks in HotKeyManager.
public struct ModifierFlags: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let control = ModifierFlags(rawValue: 1 << 0)
    public static let option  = ModifierFlags(rawValue: 1 << 1)
    public static let shift   = ModifierFlags(rawValue: 1 << 2)
    public static let command = ModifierFlags(rawValue: 1 << 3)
}

public struct Shortcut: Codable, Equatable, Sendable, Hashable {
    public var keyCode: UInt16
    public var modifiers: ModifierFlags
    public init(keyCode: UInt16, modifiers: ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// e.g. "⌥⌘←". Modifier order matches macOS: ⌃⌥⇧⌘.
    public var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + Self.keyLabel(keyCode)
    }

    static func keyLabel(_ code: UInt16) -> String {
        switch code {
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 36:  return "↩"
        case 48:  return "⇥"
        case 49:  return "Space"
        case 51:  return "⌫"
        case 53:  return "⎋"
        default:  return Self.ansiLabels[code] ?? "Key \(code)"
        }
    }

    /// ANSI virtual key codes → uppercase label (subset covering the defaults; extend as needed).
    private static let ansiLabels: [UInt16: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
        34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
        12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
        16: "Y", 6: "Z",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
    ]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ShortcutTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add ModifierFlags + Shortcut model with display formatting"
```

---

## Task 12: Default shortcut map

**Files:**
- Create: `Sources/SpectacleCore/DefaultShortcuts.swift`
- Test: `Tests/SpectacleCoreTests/DefaultShortcutsTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/SpectacleCoreTests/DefaultShortcutsTests.swift`:
```swift
import Testing
@testable import SpectacleCore

@Test func everyActionHasADefault() {
    for action in WindowAction.allCases {
        #expect(DefaultShortcuts.map[action] != nil, "missing default for \(action)")
    }
}

@Test func classicBindingsAreCorrect() {
    #expect(DefaultShortcuts.map[.center] == Shortcut(keyCode: 8, modifiers: [.option, .command]))       // ⌥⌘C
    #expect(DefaultShortcuts.map[.leftHalf]?.displayString == "⌥⌘←")
    #expect(DefaultShortcuts.map[.lowerRight]?.displayString == "⌃⇧⌘→")
    #expect(DefaultShortcuts.map[.redo]?.displayString == "⌥⇧⌘Z")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DefaultShortcutsTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

`Sources/SpectacleCore/DefaultShortcuts.swift`:
```swift
public enum DefaultShortcuts {
    public typealias Map = [WindowAction: Shortcut]

    public static let map: Map = {
        func s(_ code: UInt16, _ mods: ModifierFlags) -> Shortcut { Shortcut(keyCode: code, modifiers: mods) }
        let om: ModifierFlags = [.option, .command]
        let cm: ModifierFlags = [.control, .command]
        let csm: ModifierFlags = [.control, .shift, .command]
        let co: ModifierFlags = [.control, .option]
        let com: ModifierFlags = [.control, .option, .command]
        let cos: ModifierFlags = [.control, .option, .shift]
        return [
            .center: s(8, om), .fullscreen: s(3, om),
            .leftHalf: s(123, om), .rightHalf: s(124, om),
            .topHalf: s(126, om), .bottomHalf: s(125, om),
            .upperLeft: s(123, cm), .upperRight: s(124, cm),
            .lowerLeft: s(123, csm), .lowerRight: s(124, csm),
            .nextThird: s(124, co), .previousThird: s(123, co),
            .nextDisplay: s(124, com), .previousDisplay: s(123, com),
            .makeLarger: s(124, cos), .makeSmaller: s(123, cos),
            .undo: s(6, om), .redo: s(6, [.option, .shift, .command]),
        ]
    }()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DefaultShortcutsTests`
Expected: PASS. Then `swift test` → whole core suite green.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add default (classic Spectacle) shortcut map"
```

---

## Task 13: AccessibilityElement (AX wrapper + coordinate flip + WindowID)

Adapters are side-effectful (real windows), so they're verified by **building + running**, not unit tests, per the spec.

**Files:**
- Create: `Sources/Spectacle2/AccessibilityElement.swift`

- [ ] **Step 1: Implement**

`Sources/Spectacle2/AccessibilityElement.swift`:
```swift
import AppKit
import ApplicationServices

/// Stable identity for a window across AX calls (AX returns CFEqual-equal refs for the same
/// on-screen window). Used to key undo/redo history.
struct WindowID: Hashable {
    let element: AXUIElement
    static func == (lhs: WindowID, rhs: WindowID) -> Bool { CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

/// Reads/writes the frontmost app's focused-window frame. Owns the single AX↔Cocoa Y-flip.
final class AccessibilityElement {
    func focusedWindow() -> AXUIElement? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let v = value else { return nil }
        return (v as! AXUIElement)
    }

    func frame(of window: AXUIElement) -> CGRect? {
        guard let pos = point(window, kAXPositionAttribute),
              let size = size(window, kAXSizeAttribute) else { return nil }
        let h = primaryHeight()
        return CGRect(x: pos.x, y: h - pos.y - size.height, width: size.width, height: size.height)
    }

    func setFrame(_ cocoaRect: CGRect, of window: AXUIElement) {
        let h = primaryHeight()
        var axOrigin = CGPoint(x: cocoaRect.origin.x, y: h - cocoaRect.origin.y - cocoaRect.height)
        var size = cocoaRect.size
        // Set position, then size, then position again — some apps clamp size against the old
        // position on the first pass; the second position write lands them correctly.
        setPoint(window, kAXPositionAttribute, &axOrigin)
        setSize(window, kAXSizeAttribute, &size)
        setPoint(window, kAXPositionAttribute, &axOrigin)
    }

    // MARK: - AX value plumbing
    private func primaryHeight() -> CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    private func point(_ el: AXUIElement, _ attr: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success, let v = value else { return nil }
        var p = CGPoint.zero
        return AXValueGetValue((v as! AXValue), .cgPoint, &p) ? p : nil
    }
    private func size(_ el: AXUIElement, _ attr: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success, let v = value else { return nil }
        var s = CGSize.zero
        return AXValueGetValue((v as! AXValue), .cgSize, &s) ? s : nil
    }
    private func setPoint(_ el: AXUIElement, _ attr: String, _ p: inout CGPoint) {
        if let v = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(el, attr as CFString, v) }
    }
    private func setSize(_ el: AXUIElement, _ attr: String, _ s: inout CGSize) {
        if let v = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(el, attr as CFString, v) }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build complete!

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "Add AccessibilityElement (AX frame read/write, coordinate flip, WindowID)"
```

---

## Task 14: ScreenProvider

**Files:**
- Create: `Sources/Spectacle2/ScreenProvider.swift`

- [ ] **Step 1: Implement**

`Sources/Spectacle2/ScreenProvider.swift`:
```swift
import AppKit

/// Maps a window's Cocoa rect to source/destination visible frames for the calculator.
enum ScreenProvider {
    static func screen(containing rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
    }

    static func sourceVisibleFrame(for rect: CGRect) -> CGRect {
        (screen(containing: rect) ?? NSScreen.main)?.visibleFrame ?? .zero
    }

    /// direction: +1 next, -1 previous. Falls back to the source frame with <2 displays.
    static func destinationVisibleFrame(for rect: CGRect, direction: Int) -> CGRect {
        let ordered = NSScreen.screens.sorted {
            ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY)
        }
        guard ordered.count > 1,
              let src = screen(containing: rect),
              let idx = ordered.firstIndex(of: src) else {
            return sourceVisibleFrame(for: rect)
        }
        let count = ordered.count
        let j = ((idx + direction) % count + count) % count
        return ordered[j].visibleFrame
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build complete!

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "Add ScreenProvider (source/destination visible frames)"
```

---

## Task 15: HotKeyManager (Carbon)

**Files:**
- Create: `Sources/Spectacle2/HotKeyManager.swift`

- [ ] **Step 1: Implement**

`Sources/Spectacle2/HotKeyManager.swift`:
```swift
import Carbon.HIToolbox
import SpectacleCore

/// Wraps Carbon RegisterEventHotKey. Translates the core's neutral ModifierFlags → Carbon masks.
/// The fired hot key is mapped back to a WindowAction and delivered on the main actor.
final class HotKeyManager {
    private var refs: [EventHotKeyRef?] = []
    private var actionByID: [UInt32: WindowAction] = [:]
    private var handler: EventHandlerRef?
    private let onAction: @Sendable (WindowAction) -> Void

    init(onAction: @escaping @Sendable (WindowAction) -> Void) {
        self.onAction = onAction
        installHandler()
    }

    func register(_ map: [WindowAction: Shortcut]) {
        unregisterAll()
        var nextID: UInt32 = 1
        for action in WindowAction.allCases {
            defer { nextID += 1 }
            guard let sc = map[action] else { continue }
            let hotKeyID = EventHotKeyID(signature: OSType(0x53504332), id: nextID) // 'SPC2'
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(sc.keyCode), carbonMask(sc.modifiers),
                                             hotKeyID, GetEventDispatcherTarget(), 0, &ref)
            if status == noErr { actionByID[nextID] = action; refs.append(ref) }
        }
    }

    func unregisterAll() {
        for r in refs where r != nil { UnregisterEventHotKey(r!) }
        refs.removeAll(); actionByID.removeAll()
    }

    private func carbonMask(_ m: ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if m.contains(.command) { mask |= UInt32(cmdKey) }
        if m.contains(.option)  { mask |= UInt32(optionKey) }
        if m.contains(.control) { mask |= UInt32(controlKey) }
        if m.contains(.shift)   { mask |= UInt32(shiftKey) }
        return mask
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            if let action = manager.actionByID[hkID.id] { manager.onAction(action) }
            return noErr
        }, 1, &spec, selfPtr, &handler)
    }
}
```
> Concurrency note: if the Swift 6 compiler flags `actionByID` access from the C callback, mark
> `HotKeyManager` `@unchecked Sendable` (all mutation happens on the main thread: registration
> from the main actor, and Carbon delivers hot-key events on the main run loop). Keep `onAction`
> `@Sendable`; the controller hops to `@MainActor` in Task 16.

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build complete! (Resolve any Swift 6 Sendable diagnostics per the note.)

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "Add HotKeyManager (Carbon global hotkeys)"
```

---

## Task 16: WindowActionController (orchestrator)

**Files:**
- Create: `Sources/Spectacle2/WindowActionController.swift`

- [ ] **Step 1: Implement**

`Sources/Spectacle2/WindowActionController.swift`:
```swift
import AppKit
import ApplicationServices
import SpectacleCore

/// Glues hot keys → geometry → AX, and owns undo/redo history.
/// Invariant: only geometry moves call `history.record`; undo/redo mutate history themselves.
@MainActor
final class WindowActionController {
    private var history = WindowHistory()
    private let ax = AccessibilityElement()
    private var hotKeys: HotKeyManager?

    func start(with map: [WindowAction: Shortcut]) {
        let hk = HotKeyManager { action in
            MainActor.assumeIsolated { [weak self] in self?.perform(action) }
        }
        hk.register(map)
        hotKeys = hk
    }

    func updateShortcuts(_ map: [WindowAction: Shortcut]) { hotKeys?.register(map) }

    func perform(_ action: WindowAction) {
        guard AXIsProcessTrusted() else { return }
        guard let window = ax.focusedWindow(), let current = ax.frame(of: window) else { return }
        let id = WindowID(element: window)
        let source = ScreenProvider.sourceVisibleFrame(for: current)

        switch action {
        case .undo:
            if let f = history.undo(current: current, for: id) { ax.setFrame(f, of: window) }
        case .redo:
            if let f = history.redo(current: current, for: id) { ax.setFrame(f, of: window) }
        default:
            let dir = action == .nextDisplay ? 1 : (action == .previousDisplay ? -1 : 0)
            let dest = dir == 0 ? source : ScreenProvider.destinationVisibleFrame(for: current, direction: dir)
            let input = CalculationInput(windowRect: current, sourceVisibleFrame: source, destinationVisibleFrame: dest)
            guard let newRect = WindowCalculator.calculate(action, input) else { return }
            history.record(current, for: id)          // pre-move frame; only geometry moves record
            ax.setFrame(newRect, of: window)
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build complete!

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "Add WindowActionController orchestrator (undo/redo split honored)"
```

---

## Task 17: ShortcutStore + wire into AppDelegate

**Files:**
- Create: `Sources/Spectacle2/ShortcutStore.swift`
- Modify: `Sources/Spectacle2/AppDelegate.swift`

- [ ] **Step 1: Implement the store**

`Sources/Spectacle2/ShortcutStore.swift`:
```swift
import Foundation
import DragonKit
import SpectacleCore

/// Persists the action→shortcut map in the app's settings suite (so Backup & Restore captures it).
@MainActor
final class ShortcutStore {
    typealias Map = [WindowAction: Shortcut]
    private let store: DragonSettingsStore<Map>

    init(suiteName: String) {
        store = DragonSettingsStore(suiteName: suiteName, defaultValue: DefaultShortcuts.map)
    }

    func load() -> Map {
        // Merge in any actions missing from a persisted older map so new actions get defaults.
        var map = store.load()
        for (action, sc) in DefaultShortcuts.map where map[action] == nil { map[action] = sc }
        return map
    }
    func save(_ map: Map) { store.save(map) }
    func restoreDefaults() -> Map { store.save(DefaultShortcuts.map); return DefaultShortcuts.map }
}
```

- [ ] **Step 2: Wire the controller + store into `AppDelegate`**

In `Sources/Spectacle2/AppDelegate.swift`, add stored properties near `model`:
```swift
    private let shortcutStore = ShortcutStore(suiteName: SettingsModel.suiteName)
    private let windowActions = WindowActionController()
```
At the end of `applicationDidFinishLaunching(_:)`, after the menu-bar setup, start the engine:
```swift
        // Start the window-action engine with the persisted (or default) shortcut map.
        windowActions.start(with: shortcutStore.load())
```
Add the Shortcuts pane to `settingsPanes`, **between General and Permissions**:
```swift
            AnySettingsPane(GeneralPane(model: model)),
            AnySettingsPane(ShortcutsPane(store: shortcutStore, onChange: { [windowActions] map in
                windowActions.updateShortcuts(map)
            })),
            AnySettingsPane(PermissionsSettingsPane(permissions: [.accessibility()])),
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: FAIL — `ShortcutsPane` undefined (created in Task 18). This is expected; proceed.

- [ ] **Step 4: Commit (WIP — compiles after Task 18)**

```bash
git add Sources/Spectacle2/ShortcutStore.swift
git commit -m "Add ShortcutStore (persisted action→shortcut map with default merge)"
# Do NOT commit the AppDelegate change yet; commit it with Task 18 so the tree stays buildable.
```
Stash the AppDelegate edit until Task 18 is done, or keep it staged locally — the repo should
build green at each *committed* step, so commit AppDelegate together with Task 18.

---

## Task 18: ShortcutsPane (recorder UI) + localization

**Files:**
- Create: `Sources/Spectacle2/ShortcutsPane.swift`
- Create: `Sources/Spectacle2/ShortcutRecorderField.swift`
- Modify: all 7 `Sources/Spectacle2/Resources/*.lproj/Localizable.strings`

- [ ] **Step 1: Implement the recorder field (AppKit key capture wrapped for SwiftUI)**

`Sources/Spectacle2/ShortcutRecorderField.swift`:
```swift
import SwiftUI
import AppKit
import Carbon.HIToolbox
import SpectacleCore

/// A click-to-record control: shows the current shortcut; while recording, the next key combo
/// (with ≥1 modifier) becomes the new Shortcut. Esc cancels; Delete clears.
struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var shortcut: Shortcut?
    var onChange: (Shortcut?) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let b = RecorderButton()
        b.onCapture = { sc in shortcut = sc; onChange(sc) }
        return b
    }
    func updateNSView(_ nsView: RecorderButton, context: Context) { nsView.shortcut = shortcut }

    final class RecorderButton: NSButton {
        var shortcut: Shortcut? { didSet { title = display } }
        var onCapture: ((Shortcut?) -> Void)?
        private var recording = false { didSet { title = display } }

        override init(frame: NSRect) {
            super.init(frame: frame)
            bezelStyle = .rounded
            setButtonType(.momentaryPushIn)
            target = self; action = #selector(toggle)
        }
        required init?(coder: NSCoder) { fatalError() }

        private var display: String {
            recording ? "Recording… (Esc to cancel)" : (shortcut?.displayString ?? "Click to record")
        }

        @objc private func toggle() { recording.toggle(); if recording { window?.makeFirstResponder(self) } }
        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            if event.keyCode == UInt16(kVK_Escape) { recording = false; return }
            if event.keyCode == UInt16(kVK_Delete) { shortcut = nil; onCapture?(nil); recording = false; return }
            let mods = Self.modifierFlags(from: event.modifierFlags)
            guard !mods.isEmpty else { NSSound.beep(); return }   // require a modifier
            let sc = Shortcut(keyCode: event.keyCode, modifiers: mods)
            shortcut = sc; onCapture?(sc); recording = false
        }

        static func modifierFlags(from ns: NSEvent.ModifierFlags) -> ModifierFlags {
            var m: ModifierFlags = []
            if ns.contains(.command) { m.insert(.command) }
            if ns.contains(.option)  { m.insert(.option) }
            if ns.contains(.control) { m.insert(.control) }
            if ns.contains(.shift)   { m.insert(.shift) }
            return m
        }
    }
}
```

- [ ] **Step 2: Implement the pane**

`Sources/Spectacle2/ShortcutsPane.swift`:
```swift
import SwiftUI
import DragonKit
import SpectacleCore

struct ShortcutsPane: SettingsPane {
    let id = "shortcuts"
    let title = "app.pane.shortcuts"
    let systemImage = "keyboard"
    let store: ShortcutStore
    let onChange: (ShortcutStore.Map) -> Void

    var paneBody: some View { ShortcutsPaneView(store: store, onChange: onChange) }
}

private struct ShortcutsPaneView: View {
    let store: ShortcutStore
    let onChange: (ShortcutStore.Map) -> Void
    @State private var map: ShortcutStore.Map = [:]

    // Sidebar grouping mirrors Spectacle's preferences layout.
    private let groups: [(String, [WindowAction])] = [
        ("app.shortcuts.section.halves", [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        ("app.shortcuts.section.corners", [.upperLeft, .upperRight, .lowerLeft, .lowerRight]),
        ("app.shortcuts.section.thirds", [.nextThird, .previousThird]),
        ("app.shortcuts.section.sizing", [.center, .fullscreen, .makeLarger, .makeSmaller]),
        ("app.shortcuts.section.displays", [.nextDisplay, .previousDisplay]),
        ("app.shortcuts.section.history", [.undo, .redo]),
    ]

    var body: some View {
        DragonForm {
            ForEach(groups, id: \.0) { section in
                DragonSection(LocalizedStringKey(L(section.0))) {
                    ForEach(section.1, id: \.self) { action in
                        HStack {
                            Text(L("app.action.\(action.rawValue)"))
                            Spacer()
                            ShortcutRecorderField(
                                shortcut: Binding(
                                    get: { map[action] },
                                    set: { map[action] = $0 }
                                ),
                                onChange: { _ in store.save(map); onChange(map) }
                            )
                            .frame(width: 200)
                        }
                    }
                }
            }
            DragonSection {
                Button(L("app.shortcuts.restoreDefaults")) {
                    map = store.restoreDefaults(); onChange(map)
                }
            }
        }
        .onAppear { map = store.load() }
    }
}
```

- [ ] **Step 3: Add localization keys (English source of truth)**

Append to `Sources/Spectacle2/Resources/en.lproj/Localizable.strings`:
```
"app.pane.shortcuts" = "Shortcuts";
"app.shortcuts.section.halves" = "Halves";
"app.shortcuts.section.corners" = "Corners";
"app.shortcuts.section.thirds" = "Thirds";
"app.shortcuts.section.sizing" = "Size & Position";
"app.shortcuts.section.displays" = "Displays";
"app.shortcuts.section.history" = "History";
"app.shortcuts.restoreDefaults" = "Restore Defaults";
"app.action.center" = "Center";
"app.action.fullscreen" = "Fullscreen";
"app.action.leftHalf" = "Left Half";
"app.action.rightHalf" = "Right Half";
"app.action.topHalf" = "Top Half";
"app.action.bottomHalf" = "Bottom Half";
"app.action.upperLeft" = "Upper Left";
"app.action.upperRight" = "Upper Right";
"app.action.lowerLeft" = "Lower Left";
"app.action.lowerRight" = "Lower Right";
"app.action.nextThird" = "Next Third";
"app.action.previousThird" = "Previous Third";
"app.action.nextDisplay" = "Next Display";
"app.action.previousDisplay" = "Previous Display";
"app.action.makeLarger" = "Make Larger";
"app.action.makeSmaller" = "Make Smaller";
"app.action.undo" = "Undo Last Move";
"app.action.redo" = "Redo Last Move";
```
Then add the **same keys, translated**, to the other six `.lproj` files (`es`, `fr`, `ja`, `ko`,
`zh-Hans`, `zh-Hant`). This is a data-entry task; use the existing translated strings in each
file as the tone/style reference. (Action names are short nouns; keep "Spectacle 2" untranslated.)

- [ ] **Step 4: Build + run**

Run: `swift build`
Expected: Build complete! (AppDelegate from Task 17 now resolves `ShortcutsPane`.)

- [ ] **Step 5: Commit (with the deferred AppDelegate change from Task 17)**

```bash
git add -A
git commit -m "Add Shortcuts pane with in-app recorder + localization; wire engine into AppDelegate"
```

---

## Task 19: End-to-end verification

**Files:** none (manual verification of the running app).

- [ ] **Step 1: Full test suite + build**

Run: `swift test && swift build`
Expected: all core tests pass; Build complete!

- [ ] **Step 2: Launch the debug build**

Run: `./scripts/run.sh`
Grant Accessibility to "Spectacle 2 Debug" when prompted (System Settings → Privacy & Security →
Accessibility). The ad-hoc signature re-prompts per rebuild unless a stable "Spectacle 2 Debug"
signing identity exists.

- [ ] **Step 3: Verify each behavior manually**

With a resizable window focused (e.g. TextEdit, Finder):
- ⌥⌘← puts it on the left half; press again → ⅔; again → ⅓; again → ½ (cycling works).
- ⌥⌘→ / ⌥⌘↑ / ⌥⌘↓ halves; ⌃⌘← etc. corners; ⌥⌘C center; ⌥⌘F fullscreen.
- ⌃⌥→ / ⌃⌥← cycle through the six thirds.
- ⌃⌥⇧→ / ⌃⌥⇧← grow/shrink; won't shrink below ¼ screen.
- With two displays: ⌃⌥⌘→ / ⌃⌥⌘← move the window across displays (centered if it fits, else filled).
- ⌥⌘Z undoes the last move; ⌥⌘⇧Z redoes it; undo→redo returns to the same frame.
- Open Settings → Shortcuts: rebind an action, confirm the new shortcut works and the old one
  doesn't; "Restore Defaults" resets them; quit & relaunch → rebindings persist.

- [ ] **Step 4: Commit any fixes found during verification, then update What's New / version**

Bump `Info.plist` `CFBundleShortVersionString` when ready to cut a build, and update
`WhatsNewConfig` to describe the window-action engine.

```bash
git add -A && git commit -m "Window-action engine end-to-end verified"
```

---

## Self-review notes (author)

- **Spec coverage:** §2 actions → Tasks 2,4–9,12; §4.2 geometry → Tasks 3–9; §4.3 history →
  Task 10 (incl. the redo-not-clobbered invariant, Task 10 test 2 + the Task 16 controller split);
  §5 adapters → Tasks 13–16; §6 settings → Tasks 11,12,17,18; §5.4 undo/redo-no-record →
  Task 16; coordinate flip §5.1 → Task 13. All engine requirements have a task.
- **Out of this plan (spec §12):** release CI, Sparkle keygen/appcast, Homebrew cask,
  localization completeness beyond the keys above, MAS. Each gets its own plan.
- **Type consistency:** `CalculationInput`, `WindowCalculator.calculate`, `WindowHistory.record/
  undo/redo`, `Shortcut`, `ModifierFlags`, `DefaultShortcuts.map`, `ShortcutStore.Map`,
  `WindowID`, `WindowActionController.perform` are used identically across tasks.
