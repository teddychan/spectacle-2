# Drag-Snap, Window Gaps & Startup Deferral — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add configurable window gaps, Rectangle-parity drag-to-edge snapping, and launch-path deferral to Spectacle 2, without changing any existing default behavior.

**Architecture:** All parity-critical geometry is pure and unit-tested in `SpectacleCore` (window-tiling math, gap insets, snap-target rects, cursor→zone classification). The AppKit/AX/Carbon glue (NSEvent monitors, AX under-cursor lookup, the preview overlay, settings UI, startup ordering) lives in the `Spectacle2` executable target and is verified by `swift build` + the owner's GUI e2e pass, matching this project's established rule that AppKit/Carbon is not headlessly testable.

**Tech Stack:** Swift 6.1, SwiftPM, swift-testing (`import Testing`, `@Test`, `#expect`), AppKit, ApplicationServices (AX), Carbon hot keys, DragonKit settings/UI.

**Spec:** `docs/superpowers/specs/2026-07-10-drag-snap-gaps-startup-design.md`

**Conventions:**
- Run all unit tests: `swift test`. Run one: `swift test --filter <testFuncName>`.
- Build the app target: `swift build`.
- Commit as: `git -c user.name=teddychan -c user.email=teddychan@gmail.com commit`.
- Every commit message ends with a trailing `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` line.

---

## File Structure

**Create:**
- `Sources/SpectacleCore/WindowGap.swift` — the gap value type + the `gapInset` helper (pure).
- `Sources/SpectacleCore/SnapGeometry.swift` — `SnapTarget`, `snapRect(...)`, `SnapConstants`, `SnapZone`, `snapZone(...)`, `bottomEdgeThird(...)`, `sideEdgeHalf(...)` (all pure).
- `Sources/Spectacle2/SnapPreviewOverlay.swift` — translucent footprint window.
- `Sources/Spectacle2/DragSnapController.swift` — NSEvent monitors + drag/snap orchestration.
- `Tests/SpectacleCoreTests/GapTests.swift` — gap math tests.
- `Tests/SpectacleCoreTests/SnapGeometryTests.swift` — snap-rect + zone-classification tests.

**Modify:**
- `Sources/SpectacleCore/WindowCalculator.swift` — add `gap`/`skipGapTopEdge` to `CalculationInput`; apply gaps in `calculate`.
- `Sources/SpectacleCore/WindowActionResolver.swift` — thread `gap`/`skipGapTopEdge` through `resolve`.
- `Sources/Spectacle2/SettingsModel.swift` — new `AppSettings` fields + tolerant decoder + model accessors + notifications.
- `Sources/Spectacle2/WindowActionController.swift` — read the live gap; expose `windowUnderCursor` + `apply` for drag-snap.
- `Sources/Spectacle2/AccessibilityElement.swift` — add under-cursor window lookup.
- `Sources/Spectacle2/GeneralPane.swift` — Gaps + Snapping sections.
- `Sources/Spectacle2/AppDelegate.swift` — own/start `DragSnapController`; defer hot-key registration.
- `Sources/Spectacle2/Resources/*.lproj/Localizable.strings` (all 7) — new keys.

---

# PART A — Window Gaps

## Task A1: Add gap fields to `CalculationInput`

**Files:**
- Modify: `Sources/SpectacleCore/WindowCalculator.swift:4-13`

- [ ] **Step 1: Extend the struct (defaults keep every existing caller/test unchanged)**

Replace the `CalculationInput` struct (lines 4-13) with:

```swift
public struct CalculationInput: Equatable, Sendable {
    public var windowRect: CGRect
    public var sourceVisibleFrame: CGRect
    public var destinationVisibleFrame: CGRect
    /// Total gap (points) applied around and between tiled windows. 0 = no gaps (default).
    public var gap: CGFloat
    /// When true, no gap is applied at the top edge of the screen.
    public var skipGapTopEdge: Bool
    public init(windowRect: CGRect,
                sourceVisibleFrame: CGRect,
                destinationVisibleFrame: CGRect,
                gap: CGFloat = 0,
                skipGapTopEdge: Bool = false) {
        self.windowRect = windowRect
        self.sourceVisibleFrame = sourceVisibleFrame
        self.destinationVisibleFrame = destinationVisibleFrame
        self.gap = gap
        self.skipGapTopEdge = skipGapTopEdge
    }
}
```

- [ ] **Step 2: Verify existing tests still compile & pass**

Run: `swift test`
Expected: PASS (the new params default, so all current `CalculationInput(...)` call sites are unchanged).

- [ ] **Step 3: Commit**

```bash
git add Sources/SpectacleCore/WindowCalculator.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(core): add gap fields to CalculationInput

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task A2: The gap value type + inset helper

**Files:**
- Create: `Sources/SpectacleCore/WindowGap.swift`
- Create: `Tests/SpectacleCoreTests/GapTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/SpectacleCoreTests/GapTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import SpectacleCore

private let vf = CGRect(x: 0, y: 0, width: 1440, height: 900)

@Test func gapInsetZeroIsIdentity() {
    #expect(WindowGap.inset(vf, half: 0, skipTop: false) == vf)
}

@Test func gapInsetShrinksAllEdgesByHalf() {
    // half = 5 → 5pt off left, right, top and bottom.
    #expect(WindowGap.inset(vf, half: 5, skipTop: false)
            == CGRect(x: 5, y: 5, width: 1430, height: 890))
}

@Test func gapInsetSkipTopLeavesTopEdge() {
    // Cocoa coords: top edge is maxY. skipTop must not shrink the top → height loses only the
    // bottom 5pt, origin.y rises 5pt, maxY stays at 900.
    let r = WindowGap.inset(vf, half: 5, skipTop: true)
    #expect(r == CGRect(x: 5, y: 5, width: 1430, height: 895))
    #expect(r.maxY == vf.maxY)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter gapInsetZeroIsIdentity`
Expected: FAIL — `WindowGap` is not defined.

- [ ] **Step 3: Write the implementation**

Create `Sources/SpectacleCore/WindowGap.swift`:

```swift
import CoreGraphics

/// A window-gap setting: a total spacing (points) plus whether to skip the top edge.
/// The gap is realized as a "half-gap applied twice" — once to the working frame and once to
/// each produced rect — so outer screen edges and the space between two tiled windows both end
/// up exactly `size` points. See `WindowCalculator.calculate`.
public struct WindowGap: Equatable, Sendable {
    public var size: CGFloat
    public var skipTopEdge: Bool
    public init(size: CGFloat = 0, skipTopEdge: Bool = false) {
        self.size = size
        self.skipTopEdge = skipTopEdge
    }
    public static let none = WindowGap()

    /// Shrink `r` by `half` points on each edge. In Cocoa (bottom-left origin) the top edge is
    /// `maxY`; `skipTop` leaves it untouched. `half <= 0` returns `r` unchanged.
    public static func inset(_ r: CGRect, half: CGFloat, skipTop: Bool) -> CGRect {
        guard half > 0 else { return r }
        var out = r
        out.origin.x += half
        out.size.width -= 2 * half
        out.origin.y += half                              // bottom edge
        out.size.height -= skipTop ? half : 2 * half      // top edge optional
        return out
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter GapTests`
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add Sources/SpectacleCore/WindowGap.swift Tests/SpectacleCoreTests/GapTests.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(core): add WindowGap value type + inset helper

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task A3: Apply gaps in `WindowCalculator.calculate`

The model: shrink the working frame by `gap/2`, run the (unchanged) tiling helpers, then shrink
each *gap-applicable* result by `gap/2`. Outer edges get `gap/2 + gap/2 = gap`; adjacent tiles get
`gap/2 + gap/2 = gap` between them. Center, Make-Larger/Smaller and the "fits" branch of a display
move preserve the window's own size and are **not** gapped. The ½→⅔→⅓ cycling keeps working because
a gapped window is still contained-and-centered within its ungapped detection container.

**Files:**
- Modify: `Sources/SpectacleCore/WindowCalculator.swift:18-40`
- Modify: `Tests/SpectacleCoreTests/GapTests.swift`

- [ ] **Step 1: Write the failing tests** (append to `GapTests.swift`)

```swift
private func calcGap(_ a: WindowAction, _ win: CGRect, gap: CGFloat, skipTop: Bool = false) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(
        windowRect: win, sourceVisibleFrame: vf, destinationVisibleFrame: vf,
        gap: gap, skipGapTopEdge: skipTop))
}

@Test func gapZeroMatchesUngapped() {
    // Regression guard: gap 0 reproduces the classic left-half exactly.
    #expect(calcGap(.leftHalf, CGRect(x: 200, y: 100, width: 400, height: 300), gap: 0)
            == CGRect(x: 0, y: 0, width: 720, height: 900))
}

@Test func gapLeftHalfHasOuterAndInnerGap() {
    // gap 10 → half=5. Working frame = vf inset 5 = (5,5,1430,890); left half width floor(1430/2)=715
    // at x=5; then inset 5 → (10,10,705,880). Right edge = 715, i.e. 5 short of vf.midX (720).
    let left = calcGap(.leftHalf, CGRect(x: 0, y: 0, width: 100, height: 100), gap: 10)
    #expect(left == CGRect(x: 10, y: 10, width: 705, height: 880))
    // Right half mirrors: left edge 10pt past the midline → 10pt gap between the two halves.
    let right = calcGap(.rightHalf, CGRect(x: 0, y: 0, width: 100, height: 100), gap: 10)
    #expect(right?.minX == 725)          // 715 (working right-half x) + 10 (working inset) ... see note
}

@Test func gapFullscreenLeavesUniformMargin() {
    #expect(calcGap(.fullscreen, .zero, gap: 20) == CGRect(x: 10, y: 10, width: 1420, height: 880))
}

@Test func gapDoesNotAffectCenter() {
    // Center preserves size and centers within the TRUE visible frame regardless of gap.
    let win = CGRect(x: 0, y: 0, width: 400, height: 300)
    #expect(calcGap(.center, win, gap: 40) == WindowCalculator.calculate(.center,
        CalculationInput(windowRect: win, sourceVisibleFrame: vf, destinationVisibleFrame: vf)))
}

@Test func gapCyclingStillAdvances() {
    // A gapped left-half, pressed again, must still advance to the (gapped) two-thirds.
    let half = calcGap(.leftHalf, CGRect(x: 0, y: 0, width: 100, height: 100), gap: 10)!
    let twoThird = calcGap(.leftHalf, half, gap: 10)!
    #expect(twoThird.width > half.width)   // advanced, not stuck
}

@Test func gapSkipTopEdgeOnFullscreen() {
    // skipTop → no gap at maxY; other three edges still gapped by 20.
    let r = calcGap(.fullscreen, .zero, gap: 20, skipTop: true)!
    #expect(r.maxY == vf.maxY)
    #expect(r.minX == 10 && r.minY == 10 && r.maxX == 1430)
}
```

> **Note for the implementer:** the exact expected constant in `gapLeftHalfHasOuterAndInnerGap`
> for `right?.minX` depends on `floor` rounding; after implementing, run the test, read the actual
> value, and if it differs by the rounding of `floor(1430/2)` vs `floor(1440/2)`, update the literal
> to the computed value and add a one-line comment showing the arithmetic. The *inequality* checks
> (`twoThird.width > half.width`, `maxY` equalities) are the behavioral guards and must hold as written.

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter gapLeftHalfHasOuterAndInnerGap`
Expected: FAIL (gaps not applied yet — results equal the ungapped rects).

- [ ] **Step 3: Rewrite `calculate`** (replace lines 18-40)

```swift
    public static func calculate(_ action: WindowAction, _ input: CalculationInput) -> CGRect? {
        let win = input.windowRect
        let vf = input.destinationVisibleFrame
        let half = input.gap / 2
        let skip = input.skipGapTopEdge
        // Working frame: the visible frame shrunk by half the gap (top optional).
        let frame = WindowGap.inset(vf, half: half, skipTop: skip)
        // Gap-applicable results are shrunk by the other half; size-preserving actions are not.
        func g(_ r: CGRect) -> CGRect { WindowGap.inset(r, half: half, skipTop: skip) }
        switch action {
        case .leftHalf:   return g(leftHalf(win, frame))
        case .rightHalf:  return g(rightHalf(win, frame))
        case .topHalf:    return g(topHalf(win, frame))
        case .bottomHalf: return g(bottomHalf(win, frame))
        case .upperLeft:  return g(upperLeft(win, frame))
        case .upperRight: return g(upperRight(win, frame))
        case .lowerLeft:  return g(lowerLeft(win, frame))
        case .lowerRight: return g(lowerRight(win, frame))
        case .center:     return center(win, vf)            // size-preserving → ungapped
        case .fullscreen: return g(frame)                   // == vf inset by full gap
        case .makeLarger:  return WindowSizeAdjuster.resize(win, vf, offset: 30)
        case .makeSmaller: return WindowSizeAdjuster.resize(win, vf, offset: -30)
        case .nextThird:     return g(third(win, frame, step: +1))
        case .previousThird: return g(third(win, frame, step: -1))
        case .nextDisplay, .previousDisplay:
            return SpectacleGeometry.rectFitsWithin(win: win, screen: vf) ? center(win, vf) : g(frame)
        case .undo, .redo: return nil
        }
    }
```

- [ ] **Step 4: Run tests**

Run: `swift test`
Expected: PASS. In particular the *entire existing suite* (Halves/Corners/Thirds/etc.) still passes because those tests pass `gap: 0` (default) → `half = 0` → `WindowGap.inset` is identity and `frame == vf`. Fix any literal in `gapLeftHalfHasOuterAndInnerGap` per the Step-1 note if `floor` rounding shifts it.

- [ ] **Step 5: Commit**

```bash
git add Sources/SpectacleCore/WindowCalculator.swift Tests/SpectacleCoreTests/GapTests.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(core): apply window gaps in WindowCalculator.calculate

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task A4: Thread the gap through `WindowActionResolver.resolve`

**Files:**
- Modify: `Sources/SpectacleCore/WindowActionResolver.swift:25-48`

- [ ] **Step 1: Add gap params (defaulted, so resolver tests are unchanged)**

Replace the `resolve` signature and its `CalculationInput` construction:

```swift
    public static func resolve<ID: Hashable>(
        action: WindowAction,
        windowID: ID,
        currentFrame: CGRect,
        sourceVisibleFrame: CGRect,
        destinationVisibleFrame: CGRect,
        gap: CGFloat = 0,
        skipGapTopEdge: Bool = false,
        history: inout WindowHistory
    ) -> WindowActionOutcome {
        switch action {
        case .undo:
            return history.undo(current: currentFrame, for: windowID).map(WindowActionOutcome.move) ?? .noop
        case .redo:
            return history.redo(current: currentFrame, for: windowID).map(WindowActionOutcome.move) ?? .noop
        default:
            let input = CalculationInput(
                windowRect: currentFrame,
                sourceVisibleFrame: sourceVisibleFrame,
                destinationVisibleFrame: destinationVisibleFrame,
                gap: gap,
                skipGapTopEdge: skipGapTopEdge
            )
            guard let newRect = WindowCalculator.calculate(action, input) else { return .noop }
            history.record(currentFrame, for: windowID)
            return .move(newRect)
        }
    }
```

> `history` stays the trailing argument, so existing call sites that pass `history: &history` as
> the last labeled argument still compile. Verify `WindowActionResolverTests` compiles unchanged.

- [ ] **Step 2: Run tests**

Run: `swift test`
Expected: PASS (resolver tests use the defaulted gap = 0).

- [ ] **Step 3: Commit**

```bash
git add Sources/SpectacleCore/WindowActionResolver.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(core): thread window gap through WindowActionResolver

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task A5: `AppSettings` — new fields + tolerant decoder

**Why a custom decoder:** `DragonSettingsStore.load()` uses `try?` and returns `defaultValue` on
*any* decode error, and Swift's synthesized `Decodable` throws `keyNotFound` for missing keys (it
does **not** apply property defaults). Without a hand-written `init(from:)`, existing users' stored
JSON (which lacks the new keys) would fail to decode and silently reset **all** settings, wiping
`launchAtLogin`/`showInMenuBar`. The tolerant decoder below is correct by construction
(`decodeIfPresent ?? default` for every field). **Verification is by inspection + the owner e2e
upgrade check in Task C7-verify**, because the app executable target has no unit-test target and
adding one for an `@main` executable is out of scope.

**Files:**
- Modify: `Sources/Spectacle2/SettingsModel.swift:8-11` and `:41-56`

- [ ] **Step 1: Replace the `AppSettings` struct (lines 8-11)**

```swift
struct AppSettings: Codable, Sendable, Equatable {
    var launchAtLogin = false
    var showInMenuBar = true
    var gapSize: Double = 0
    var skipGapTopEdge = false
    var dragSnapEnabled = true

    init() {}

    // Tolerant decoder: old payloads (only launchAtLogin/showInMenuBar) must decode cleanly, with
    // the new fields taking their defaults. Synthesized Decodable would throw on the missing keys
    // and reset everything (DragonSettingsStore.load falls back to defaultValue on any error).
    enum CodingKeys: String, CodingKey {
        case launchAtLogin, showInMenuBar, gapSize, skipGapTopEdge, dragSnapEnabled
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
        gapSize = try c.decodeIfPresent(Double.self, forKey: .gapSize) ?? 0
        skipGapTopEdge = try c.decodeIfPresent(Bool.self, forKey: .skipGapTopEdge) ?? false
        dragSnapEnabled = try c.decodeIfPresent(Bool.self, forKey: .dragSnapEnabled) ?? true
    }
}
```

- [ ] **Step 2: Add notifications (after the existing `spectacleShowInMenuBarChanged`, line 13-17)**

```swift
extension Notification.Name {
    /// Posted when the drag-snap enabled flag changes, so the AppDelegate can start/stop the
    /// DragSnapController.
    static let spectacleDragSnapEnabledChanged = Notification.Name("spectacleDragSnapEnabledChanged")
}
```

- [ ] **Step 3: Add model accessors (after `showInMenuBar`, before the closing brace ~line 55)**

```swift
    var gapSize: Double {
        get { settings.gapSize }
        set { settings.gapSize = max(0, min(newValue, 100)) }   // sane clamp; recomputed per action
    }

    var skipGapTopEdge: Bool {
        get { settings.skipGapTopEdge }
        set { settings.skipGapTopEdge = newValue }
    }

    var dragSnapEnabled: Bool {
        get { settings.dragSnapEnabled }
        set {
            settings.dragSnapEnabled = newValue
            NotificationCenter.default.post(name: .spectacleDragSnapEnabledChanged, object: newValue)
        }
    }
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 5: Commit**

```bash
git add Sources/Spectacle2/SettingsModel.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(app): add gap + drag-snap settings with migration-safe decoder

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task A6: Feed the live gap into keyboard actions

**Files:**
- Modify: `Sources/Spectacle2/WindowActionController.swift`
- Modify: `Sources/Spectacle2/AppDelegate.swift:123`

- [ ] **Step 1: Add a gap provider + use it in `perform`**

In `WindowActionController` add a stored provider and read it each `perform`:

```swift
    /// Supplies the current gap on every action, so changing the setting takes effect immediately
    /// without re-registering hot keys. Defaults to no gap until the app wires it.
    var gapProvider: @MainActor () -> (size: CGFloat, skipTop: Bool) = { (0, false) }
```

Then in `perform`, replace the `resolve(...)` call (lines 41-43) with:

```swift
        let (gapSize, skipTop) = gapProvider()
        let outcome = WindowActionResolver.resolve(
            action: action, windowID: id, currentFrame: current,
            sourceVisibleFrame: source, destinationVisibleFrame: dest,
            gap: gapSize, skipGapTopEdge: skipTop, history: &history)
```

- [ ] **Step 2: Wire the provider in AppDelegate**

In `applicationDidFinishLaunching`, immediately before `windowActions.start(...)` (line 123), add:

```swift
        windowActions.gapProvider = { [model] in
            (CGFloat(model.gapSize), model.skipGapTopEdge)
        }
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 4: Commit**

```bash
git add Sources/Spectacle2/WindowActionController.swift Sources/Spectacle2/AppDelegate.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(app): apply the configured gap to keyboard window actions

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task A7: Gaps UI + localization

**Files:**
- Modify: `Sources/Spectacle2/GeneralPane.swift`
- Modify: all 7 `Sources/Spectacle2/Resources/*.lproj/Localizable.strings`

- [ ] **Step 1: Add the localization keys to ALL 7 files**

Append these lines to each `Localizable.strings`. Use the row for that file's language:

| Key | en | zh-Hans | zh-Hant | ja | ko | es | fr |
|---|---|---|---|---|---|---|---|
| `app.general.gaps` | Window Gaps | 窗口间距 | 視窗間距 | ウインドウの間隔 | 창 간격 | Espaciado de ventanas | Espacement des fenêtres |
| `app.general.gapSize` | Gap size | 间距大小 | 間距大小 | 間隔のサイズ | 간격 크기 | Tamaño del espacio | Taille de l’espace |
| `app.general.gapSizeHint` | Spacing in points around and between tiled windows. Set to 0 to disable. | 平铺窗口周围及彼此之间的间距（点）。设为 0 可关闭。 | 平鋪視窗周圍及彼此之間的間距（點）。設為 0 可關閉。 | タイル表示したウインドウの周囲と相互の間隔（ポイント）。0 で無効になります。 | 타일 배치된 창 주위와 창 사이의 간격(포인트)입니다. 0으로 설정하면 비활성화됩니다. | Espacio en puntos alrededor y entre las ventanas en mosaico. Ponlo a 0 para desactivarlo. | Espace en points autour et entre les fenêtres en mosaïque. Réglez sur 0 pour désactiver. |
| `app.general.skipTopGap` | Skip gap at the top edge | 顶部边缘不留间距 | 頂部邊緣不留間距 | 上端では間隔を空けない | 위쪽 가장자리는 간격 제외 | Omitir el espacio en el borde superior | Ignorer l’espace sur le bord supérieur |
| `app.general.snapping` | Snapping | 吸附 | 吸附 | スナップ | 스냅 | Ajuste | Ancrage |
| `app.general.dragSnap` | Snap windows dragged to screen edges | 拖到屏幕边缘时吸附窗口 | 拖到螢幕邊緣時吸附視窗 | 画面端へのドラッグでウインドウをスナップ | 화면 가장자리로 끌 때 창 스냅 | Ajustar ventanas al arrastrarlas a los bordes de la pantalla | Ancrer les fenêtres glissées vers les bords de l’écran |
| `app.general.dragSnapHint` | Drag a window to a screen edge or corner to snap it into place. | 将窗口拖到屏幕边缘或角落即可将其吸附到位。 | 將視窗拖到螢幕邊緣或角落即可將其吸附到位。 | ウインドウを画面の端や隅にドラッグすると所定の位置にスナップします。 | 창을 화면 가장자리나 모서리로 끌면 제자리에 스냅됩니다. | Arrastra una ventana a un borde o esquina de la pantalla para ajustarla en su sitio. | Faites glisser une fenêtre a un borde o esquina de la pantalla para ajustarla en su sitio. |

Format each line as `"<key>" = "<value>";` (matching the existing file style; escape any `"` inside values — none of the above contain quotes). **Fix the last `fr` cell** to the correct French (the table cell above is a copy error): use `"Faites glisser une fenêtre vers un bord ou un coin de l’écran pour l’ancrer en place.";`

- [ ] **Step 2: Add the UI sections to `GeneralPaneView.body`**

In `GeneralPane.swift`, insert these two `DragonSection`s after the Menu Bar section and before the Language section:

```swift
            DragonSection(LocalizedStringKey(L("app.general.gaps"))) {
                Stepper(value: $model.gapSize, in: 0...100, step: 2) {
                    Text("\(L("app.general.gapSize")): \(Int(model.gapSize)) pt")
                }
                .dragonAnnotation(LocalizedStringKey(L("app.general.gapSizeHint")))
                Toggle(L("app.general.skipTopGap"), isOn: $model.skipGapTopEdge)
            }
            DragonSection(LocalizedStringKey(L("app.general.snapping"))) {
                Toggle(L("app.general.dragSnap"), isOn: $model.dragSnapEnabled)
                    .dragonAnnotation(LocalizedStringKey(L("app.general.dragSnapHint")))
            }
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 4: Commit**

```bash
git add Sources/Spectacle2/GeneralPane.swift Sources/Spectacle2/Resources
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(app): General-pane UI for window gaps and drag-snap toggle

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

# PART B — Startup Deferral

## Task B1: Defer hot-key registration off the launch path

**Files:**
- Modify: `Sources/Spectacle2/AppDelegate.swift:122-123`

- [ ] **Step 1: Wrap the engine start in a next-tick dispatch**

Replace the `windowActions.start(with: shortcutStore.load())` line (123) with:

```swift
        // Register the 18 global hot keys after the first runloop tick so 18 synchronous Carbon
        // RegisterEventHotKey calls don't block applicationDidFinishLaunching returning. A hot key
        // pressed in the first few ms simply won't fire yet — acceptable.
        let map = shortcutStore.load()
        DispatchQueue.main.async { [windowActions] in
            windowActions.start(with: map)
        }
```

> Keep the `gapProvider` assignment from Task A6 **before** this block (synchronous), so the
> provider is set before the first action can fire.

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/Spectacle2/AppDelegate.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "perf(app): register hot keys after first runloop tick

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task B2: Defer the login-item reconcile

**Files:**
- Modify: `Sources/Spectacle2/SettingsModel.swift:33-39`

- [ ] **Step 1: Move the SMAppService reconcile off `init`**

Replace the reconcile call inside `init` (the `LoginItem.setEnabled(settings.launchAtLogin)` line) so `init` no longer performs the synchronous ServiceManagement call:

```swift
    init() {
        let store = DragonSettingsStore(suiteName: Self.suiteName, defaultValue: AppSettings())
        self.store = store
        self.settings = store.load()
        // Reconcile the OS login-item state off the launch critical path (SMAppService is a
        // synchronous ServiceManagement call). The persisted preference is unchanged.
        let enabled = settings.launchAtLogin
        DispatchQueue.main.async { LoginItem.setEnabled(enabled) }
    }
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/Spectacle2/SettingsModel.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "perf(app): reconcile login item asynchronously after launch

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

# PART C — Drag-to-Edge Snapping

## Task C1: Snap targets + gap-aware snap rects (pure)

**Files:**
- Create: `Sources/SpectacleCore/SnapGeometry.swift`
- Create: `Tests/SpectacleCoreTests/SnapGeometryTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/SpectacleCoreTests/SnapGeometryTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import SpectacleCore

private let vf = CGRect(x: 0, y: 0, width: 1440, height: 900)

@Test func snapLeftHalfNoGap() {
    #expect(SnapGeometry.rect(.leftHalf, visibleFrame: vf, gap: .none)
            == CGRect(x: 0, y: 0, width: 720, height: 900))
}

@Test func snapMaximizeNoGap() {
    #expect(SnapGeometry.rect(.maximize, visibleFrame: vf, gap: .none) == vf)
}

@Test func snapTopLeftQuarterNoGap() {
    // Cocoa top-left quarter: upper-left corner of the screen.
    #expect(SnapGeometry.rect(.topLeft, visibleFrame: vf, gap: .none)
            == CGRect(x: 0, y: 450, width: 720, height: 450))
}

@Test func snapThirdsPartitionTheWidth() {
    let first = SnapGeometry.rect(.firstThird, visibleFrame: vf, gap: .none)
    let center = SnapGeometry.rect(.centerThird, visibleFrame: vf, gap: .none)
    let last = SnapGeometry.rect(.lastThird, visibleFrame: vf, gap: .none)
    #expect(first.minX == 0)
    #expect(center.minX == first.maxX)
    #expect(last.maxX == vf.maxX)
    #expect(first.width == 480 && center.width == 480 && last.width == 480)
}

@Test func snapTwoThirdsSpanTwoColumns() {
    let firstTwo = SnapGeometry.rect(.firstTwoThirds, visibleFrame: vf, gap: .none)
    #expect(firstTwo.minX == 0 && firstTwo.width == 960)
    let lastTwo = SnapGeometry.rect(.lastTwoThirds, visibleFrame: vf, gap: .none)
    #expect(lastTwo.maxX == vf.maxX && lastTwo.width == 960)
}

@Test func snapAppliesGap() {
    // gap 10 → left half becomes the same rect WindowCalculator produces for a fresh left-half.
    let snapped = SnapGeometry.rect(.leftHalf, visibleFrame: vf, gap: WindowGap(size: 10))
    #expect(snapped == CGRect(x: 10, y: 10, width: 705, height: 880))
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter snapLeftHalfNoGap`
Expected: FAIL — `SnapGeometry` undefined.

- [ ] **Step 3: Implement**

Create `Sources/SpectacleCore/SnapGeometry.swift`:

```swift
import CoreGraphics

/// A drag-snap landing target. Unlike `WindowCalculator` these never cycle (½→⅔→⅓) — a fresh
/// drag-snap always produces the plain tile — but they honor the configured `WindowGap`.
public enum SnapTarget: Equatable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight   // quarters
    case maximize
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
}

public enum SnapGeometry {
    /// The Cocoa (bottom-left origin) rect for `target` within `visibleFrame`, with `gap` applied.
    public static func rect(_ target: SnapTarget, visibleFrame vf: CGRect, gap: WindowGap) -> CGRect {
        let half = gap.size / 2
        let f = WindowGap.inset(vf, half: half, skipTop: gap.skipTopEdge)   // working frame
        let w2 = floor(f.width / 2), h2 = floor(f.height / 2)
        let topY = f.minY + h2                       // bottom of the upper row (Cocoa)
        let w3 = floor(f.width / 3), w23 = floor(f.width * 2 / 3)
        let plain: CGRect
        switch target {
        case .leftHalf:    plain = CGRect(x: f.minX, y: f.minY, width: w2, height: f.height)
        case .rightHalf:   plain = CGRect(x: f.maxX - w2, y: f.minY, width: w2, height: f.height)
        case .topHalf:     plain = CGRect(x: f.minX, y: topY, width: f.width, height: f.maxY - topY)
        case .bottomHalf:  plain = CGRect(x: f.minX, y: f.minY, width: f.width, height: h2)
        case .topLeft:     plain = CGRect(x: f.minX, y: topY, width: w2, height: f.maxY - topY)
        case .topRight:    plain = CGRect(x: f.maxX - w2, y: topY, width: w2, height: f.maxY - topY)
        case .bottomLeft:  plain = CGRect(x: f.minX, y: f.minY, width: w2, height: h2)
        case .bottomRight: plain = CGRect(x: f.maxX - w2, y: f.minY, width: w2, height: h2)
        case .maximize:    return WindowGap.inset(f, half: half, skipTop: gap.skipTopEdge)
        case .firstThird:  plain = CGRect(x: f.minX, y: f.minY, width: w3, height: f.height)
        case .centerThird: plain = CGRect(x: f.minX + w3, y: f.minY, width: w3, height: f.height)
        case .lastThird:   plain = CGRect(x: f.maxX - w3, y: f.minY, width: w3, height: f.height)
        case .firstTwoThirds: plain = CGRect(x: f.minX, y: f.minY, width: w23, height: f.height)
        case .lastTwoThirds:  plain = CGRect(x: f.maxX - w23, y: f.minY, width: w23, height: f.height)
        }
        return WindowGap.inset(plain, half: half, skipTop: gap.skipTopEdge)
    }
}
```

> The `topY`/height arithmetic uses simple halves (drag-snap targets don't need the
> `truncatingRemainder` top-row correction that keyboard halves use; a 1px seam on odd heights is
> invisible and matches Rectangle's `floor` split). If a test wants pixel-exactness against the
> keyboard halves later, revisit — not needed for parity.

- [ ] **Step 4: Run tests**

Run: `swift test --filter SnapGeometryTests`
Expected: PASS. (`snapAppliesGap` expects the same rect as `WindowCalculator`'s gapped left-half from Task A3 — confirm the constant matches; adjust the literal to the computed value if `floor` rounding differs, keeping the comment.)

- [ ] **Step 5: Commit**

```bash
git add Sources/SpectacleCore/SnapGeometry.swift Tests/SpectacleCoreTests/SnapGeometryTests.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(core): gap-aware drag-snap target rects

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task C2: Cursor → zone classification (pure)

Rectangle constants: edge margin 5pt, corner box 20pt (→ 25pt corner band), short-edge 145pt.
Detection is in Cocoa coords against the screen's full frame. Corners win over edges.

**Files:**
- Modify: `Sources/SpectacleCore/SnapGeometry.swift`
- Modify: `Tests/SpectacleCoreTests/SnapGeometryTests.swift`

- [ ] **Step 1: Write the failing tests** (append)

```swift
private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)   // Cocoa: minY bottom, maxY top

@Test func zoneNilInInterior() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 700, y: 450), in: screen) == nil)
}
@Test func zoneTopEdge() {
    // near maxY (top), away from corners → .top
    #expect(SnapGeometry.zone(for: CGPoint(x: 700, y: 898), in: screen) == .top)
}
@Test func zoneBottomEdge() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 700, y: 2), in: screen) == .bottom)
}
@Test func zoneLeftEdge() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 2, y: 450), in: screen) == .left)
}
@Test func zoneCornerTopLeftWins() {
    // within 25pt of both the left and the top → corner, not edge
    #expect(SnapGeometry.zone(for: CGPoint(x: 3, y: 890), in: screen) == .topLeft)
}
@Test func zoneCornerBottomRight() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 1438, y: 3), in: screen) == .bottomRight)
}

@Test func sideHalfNearTopCorner() {
    // On the left edge within 145pt of the top → top half; middle → nil (plain left half)
    #expect(SnapGeometry.sideEdgeHalf(cursorY: 850, in: screen) == .topHalf)
    #expect(SnapGeometry.sideEdgeHalf(cursorY: 50, in: screen) == .bottomHalf)
    #expect(SnapGeometry.sideEdgeHalf(cursorY: 450, in: screen) == nil)
}

@Test func bottomEdgeThirdByCursorX() {
    #expect(SnapGeometry.bottomEdgeThird(cursorX: 100, in: screen) == .first)
    #expect(SnapGeometry.bottomEdgeThird(cursorX: 720, in: screen) == .center)
    #expect(SnapGeometry.bottomEdgeThird(cursorX: 1400, in: screen) == .last)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter zoneTopEdge`
Expected: FAIL — `SnapGeometry.zone` undefined.

- [ ] **Step 3: Implement** (append to `SnapGeometry.swift`, inside the `enum SnapGeometry`)

```swift
    public enum SnapZone: Equatable, Sendable {
        case top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight
    }
    public enum ThirdColumn: Equatable, Sendable { case first, center, last }

    /// Rectangle default zone geometry (points).
    public static let edgeMargin: CGFloat = 5
    public static let cornerSize: CGFloat = 20        // → 25pt corner band with the 5pt margin
    public static let shortEdgeSize: CGFloat = 145

    /// The zone the cursor is in for a screen (Cocoa coords), or nil if in the interior.
    /// Corners take priority over edges.
    public static func zone(for c: CGPoint, in s: CGRect) -> SnapZone? {
        guard s.contains(c) else { return nil }
        let band = edgeMargin + cornerSize                    // 25
        let nearLeft = c.x < s.minX + band
        let nearRight = c.x > s.maxX - band
        let nearTop = c.y > s.maxY - band                     // Cocoa: top = maxY
        let nearBottom = c.y < s.minY + band
        if nearLeft && nearTop { return .topLeft }
        if nearRight && nearTop { return .topRight }
        if nearLeft && nearBottom { return .bottomLeft }
        if nearRight && nearBottom { return .bottomRight }
        if c.x < s.minX + edgeMargin { return .left }
        if c.x > s.maxX - edgeMargin { return .right }
        if c.y > s.maxY - edgeMargin { return .top }
        if c.y < s.minY + edgeMargin { return .bottom }
        return nil
    }

    /// On a left/right edge: within `shortEdgeSize` of the top → top half, of the bottom → bottom
    /// half, else nil (→ plain side half). Cocoa coords.
    public static func sideEdgeHalf(cursorY y: CGFloat, in s: CGRect) -> SnapTarget? {
        if y >= s.maxY - shortEdgeSize { return .topHalf }
        if y <= s.minY + shortEdgeSize { return .bottomHalf }
        return nil
    }

    /// Which horizontal third the cursor's x falls in.
    public static func bottomEdgeThird(cursorX x: CGFloat, in s: CGRect) -> ThirdColumn {
        let third = s.width / 3
        if x <= s.minX + third { return .first }
        if x >= s.maxX - third { return .last }
        return .center
    }
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter SnapGeometryTests`
Expected: PASS (all zone/side/third tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SpectacleCore/SnapGeometry.swift Tests/SpectacleCoreTests/SnapGeometryTests.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(core): Rectangle-parity cursor-to-snap-zone classification

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task C3: AX under-cursor window lookup

**Files:**
- Modify: `Sources/Spectacle2/AccessibilityElement.swift`

- [ ] **Step 1: Add the lookup (append inside `AccessibilityElement`, after `setFrame`)**

```swift
    /// The window element under a Cocoa (bottom-left, global) point, or nil. Uses the system-wide
    /// element and walks up to the enclosing window. Converts to AX's top-left global space first.
    func windowUnderCursor(atCocoaPoint p: CGPoint) -> AXUIElement? {
        guard !NSScreen.screens.isEmpty else { return nil }
        let axY = primaryHeight() - p.y                       // Cocoa bottom-left → AX top-left
        var hit: AXUIElement?
        let sys = AXUIElementCreateSystemWide()
        guard AXUIElementCopyElementAtPosition(sys, Float(p.x), Float(axY), &hit) == .success,
              var el = hit else { return nil }
        // Walk parents until we reach a window-role element (max a few hops).
        for _ in 0..<12 {
            if role(of: el) == (kAXWindowRole as String) { return el }
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parent) == .success,
                  let p = parent else { return nil }
            el = (p as! AXUIElement)
        }
        return nil
    }

    private func role(of el: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/Spectacle2/AccessibilityElement.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(app): AX window-under-cursor lookup for drag-snap

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task C4: Shared apply/read entry points on `WindowActionController`

So drag-snaps record into the **same** `WindowHistory` (undo parity) and reuse the AX plumbing.

**Files:**
- Modify: `Sources/Spectacle2/WindowActionController.swift`

- [ ] **Step 1: Add public helpers (append inside the class)**

```swift
    /// The window under a Cocoa point and its current Cocoa frame — for drag-snap acquisition.
    func windowUnderCursor(atCocoaPoint p: CGPoint) -> (window: AXUIElement, id: WindowID, frame: CGRect)? {
        guard AXIsProcessTrusted(), let w = ax.windowUnderCursor(atCocoaPoint: p),
              let f = ax.frame(of: w) else { return nil }
        return (w, WindowID(element: w), f)
    }

    /// Current Cocoa frame of a known window.
    func frame(of window: AXUIElement) -> CGRect? { ax.frame(of: window) }

    /// Apply a frame from outside the hot-key path (drag-snap). `record: true` pushes the pre-move
    /// frame so ⌘Z undoes the snap; `record: false` (unsnap-restore) does not touch history.
    func apply(_ newRect: CGRect, to window: AXUIElement, id: WindowID, currentFrame: CGRect, record: Bool) {
        guard AXIsProcessTrusted() else { return }
        if record { history.record(currentFrame, for: id) }
        ax.setFrame(newRect, of: window)
    }
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/Spectacle2/WindowActionController.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(app): shared apply/read entry points for drag-snap history parity

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task C5: The footprint preview overlay

**Files:**
- Create: `Sources/Spectacle2/SnapPreviewOverlay.swift`

- [ ] **Step 1: Implement the overlay**

```swift
import AppKit

/// A translucent borderless window that previews the snap target during a drag. Styling mirrors
/// Rectangle's footprint: ~30% black fill, light-gray 2pt border, rounded corners.
@MainActor
final class SnapPreviewOverlay {
    private let window: NSWindow
    private let box: NSBox

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .modalPanel
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.transient, .canJoinAllSpaces, .ignoresCycle]

        box = NSBox()
        box.boxType = .custom
        box.borderWidth = 2
        box.borderColor = .lightGray
        box.cornerRadius = 16
        box.fillColor = NSColor.black.withAlphaComponent(0.3)
        box.titlePosition = .noTitle
        box.contentViewMargins = .zero
        box.translatesAutoresizingMaskIntoConstraints = true
        box.autoresizingMask = [.width, .height]
        let content = NSView(frame: .zero)
        content.addSubview(box)
        window.contentView = content
    }

    /// Show the overlay at a Cocoa screen rect (same coordinate space as `SnapGeometry.rect`).
    func show(at rect: CGRect) {
        window.setFrame(rect, display: true)
        box.frame = window.contentView?.bounds ?? .zero
        if !window.isVisible { window.orderFront(nil) }
    }

    func hide() {
        if window.isVisible { window.orderOut(nil) }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/Spectacle2/SnapPreviewOverlay.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(app): translucent snap-preview overlay window

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task C6: `DragSnapController` — monitors + orchestration

Maps zones → `SnapTarget`, previews via the overlay, snaps on drop, and does unsnap-restore.
Two-thirds promotion on the bottom edge is driven by the previous zone within a single drag.

**Files:**
- Create: `Sources/Spectacle2/DragSnapController.swift`

- [ ] **Step 1: Implement the controller**

```swift
import AppKit
import ApplicationServices
import SpectacleCore

/// Rectangle-parity drag-to-edge snapping. Passive NSEvent monitors observe the left mouse; on a
/// real move it previews the target zone and, on release, snaps the window under the cursor.
@MainActor
final class DragSnapController {
    private let controller: WindowActionController
    private let gapProvider: @MainActor () -> WindowGap
    private let overlay = SnapPreviewOverlay()

    private var localMonitor: Any?
    private var globalMonitor: Any?

    // Per-drag state.
    private var window: AXUIElement?
    private var windowID: WindowID?
    private var initialFrame: CGRect?
    private var moving = false
    private var currentTarget: SnapTarget?
    private var lastBottomColumn: SnapGeometry.ThirdColumn?
    private var restoreRect: CGRect?          // captured pre-snap size, for unsnap-restore

    init(controller: WindowActionController, gapProvider: @escaping @MainActor () -> WindowGap) {
        self.controller = controller
        self.gapProvider = gapProvider
    }

    var isRunning: Bool { globalMonitor != nil }

    func start() {
        guard globalMonitor == nil, AXIsProcessTrusted() else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .leftMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] e in
            self?.handle(e)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] e in
            self?.handle(e); return e
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        resetDrag()
    }

    private func handle(_ e: NSEvent) {
        switch e.type {
        case .leftMouseDown: beginCapture()
        case .leftMouseDragged: continueDrag()
        case .leftMouseUp: endDrag()
        default: break
        }
    }

    private func beginCapture() {
        // Capture the window under the cursor; snapping arms only once it actually moves.
        let p = NSEvent.mouseLocation
        guard let hit = controller.windowUnderCursor(atCocoaPoint: p) else { resetDrag(); return }
        window = hit.window; windowID = hit.id; initialFrame = hit.frame
        moving = false; currentTarget = nil; lastBottomColumn = nil; restoreRect = nil
    }

    private func continueDrag() {
        guard let window, let windowID, let initial = initialFrame,
              let live = controller.frame(of: window) else { return }

        if !moving {
            // Arm only on a real move (origin changed, size unchanged = a move, not a resize).
            guard live.origin != initial.origin,
                  abs(live.width - initial.width) < 1, abs(live.height - initial.height) < 1 else { return }
            moving = true
            unsnapRestoreIfNeeded(window: window, id: windowID, live: live)
        }

        let cursor = NSEvent.mouseLocation
        guard let screen = screenFrame(containing: cursor), let zone = SnapGeometry.zone(for: cursor, in: screen) else {
            currentTarget = nil; lastBottomColumn = nil; overlay.hide(); return
        }
        let target = mapZoneToTarget(zone, cursor: cursor, screen: screen)
        currentTarget = target
        let vf = visibleFrame(forScreenFrame: screen)
        overlay.show(at: SnapGeometry.rect(target, visibleFrame: vf, gap: gapProvider()))
    }

    private func endDrag() {
        defer { resetDrag() }
        overlay.hide()
        guard moving, let window, let windowID, let target = currentTarget,
              let live = controller.frame(of: window),
              let screen = screenFrame(containing: NSEvent.mouseLocation) else { return }
        let vf = visibleFrame(forScreenFrame: screen)
        let rect = SnapGeometry.rect(target, visibleFrame: vf, gap: gapProvider())
        controller.apply(rect, to: window, id: windowID, currentFrame: live, record: true)
    }

    // MARK: - Zone → target (incl. bottom-edge thirds + two-thirds promotion)

    private func mapZoneToTarget(_ zone: SnapGeometry.SnapZone, cursor: CGPoint, screen: CGRect) -> SnapTarget {
        switch zone {
        case .top: return .maximize
        case .topLeft: return .topLeft
        case .topRight: return .topRight
        case .bottomLeft: return .bottomLeft
        case .bottomRight: return .bottomRight
        case .left:
            return SnapGeometry.sideEdgeHalf(cursorY: cursor.y, in: screen) ?? .leftHalf
        case .right:
            return SnapGeometry.sideEdgeHalf(cursorY: cursor.y, in: screen) ?? .rightHalf
        case .bottom:
            let col = SnapGeometry.bottomEdgeThird(cursorX: cursor.x, in: screen)
            defer { lastBottomColumn = col }
            // Two-thirds promotion: entering the center third from a side third widens to two-thirds.
            if col == .center, let prev = lastBottomColumn {
                if prev == .first { return .firstTwoThirds }
                if prev == .last { return .lastTwoThirds }
            }
            switch col {
            case .first: return .firstThird
            case .center: return .centerThird
            case .last: return .lastThird
            }
        }
    }

    // MARK: - Unsnap-restore

    private func unsnapRestoreIfNeeded(window: AXUIElement, id: WindowID, live: CGRect) {
        // If we have a stored pre-snap size, restore it mid-drag and keep the window under the
        // cursor. (We store the restore rect on the first move of any drag we don't restore.)
        if let restore = restoreRect {
            var r = restore
            let cursor = NSEvent.mouseLocation
            r.origin.x = min(max(cursor.x - r.width / 2, live.minX), live.maxX - r.width)
            r.origin.y = live.maxY - r.height
            controller.apply(r, to: window, id: id, currentFrame: live, record: false)
            restoreRect = nil
        } else {
            restoreRect = live
        }
    }

    // MARK: - Screen helpers

    private func screenFrame(containing p: CGPoint) -> CGRect? {
        NSScreen.screens.first { $0.frame.contains(p) }?.frame
    }
    private func visibleFrame(forScreenFrame f: CGRect) -> CGRect {
        (NSScreen.screens.first { $0.frame == f } ?? NSScreen.main)?.visibleFrame ?? f
    }

    private func resetDrag() {
        window = nil; windowID = nil; initialFrame = nil
        moving = false; currentTarget = nil; lastBottomColumn = nil
    }
}
```

> **Unsnap-restore is intentionally simpler than Rectangle's** (no last-action equality check): it
> records the grab-time frame and, on the *next* drag of the same session, restores it. This matches
> the spec's "shrink back to pre-snap size / keep under cursor" intent without replicating
> Rectangle's full `lastRectangleActions` bookkeeping (deferred). If e2e shows it feels wrong,
> revisit — it's isolated to this method.

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/Spectacle2/DragSnapController.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(app): Rectangle-parity DragSnapController

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task C7: Wire `DragSnapController` into `AppDelegate`

**Files:**
- Modify: `Sources/Spectacle2/AppDelegate.swift`

- [ ] **Step 1: Add the stored controller (after `windowActions`, line 18)**

```swift
    private var dragSnap: DragSnapController?
```

- [ ] **Step 2: Create/start it + observe the toggle** — in `applicationDidFinishLaunching`, inside the deferred block from Task B1, after `windowActions.start(with: map)`:

```swift
            let snap = DragSnapController(
                controller: windowActions,
                gapProvider: { [model] in WindowGap(size: CGFloat(model.gapSize), skipTopEdge: model.skipGapTopEdge) }
            )
            if model.showInMenuBar || true, model.dragSnapEnabled { snap.start() }
            self.dragSnap = snap
```

> Simplify the condition to just `if model.dragSnapEnabled { snap.start() }` — the `|| true` above is
> a typo guard; use the clean form.

Add an observer registration next to the existing two `addObserver` calls (after line 114):

```swift
        NotificationCenter.default.addObserver(
            self, selector: #selector(dragSnapEnabledChanged(_:)),
            name: .spectacleDragSnapEnabledChanged, object: nil)
```

And the handler (near `showInMenuBarChanged`, ~line 200):

```swift
    @objc private func dragSnapEnabledChanged(_ note: Notification) {
        let enabled = (note.object as? Bool) ?? true
        if enabled { dragSnap?.start() } else { dragSnap?.stop() }
    }
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 4: Commit**

```bash
git add Sources/Spectacle2/AppDelegate.swift
git -c user.name=teddychan -c user.email=teddychan@gmail.com commit -m "feat(app): own and toggle DragSnapController from AppDelegate

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task C7-verify: Full build + owner GUI e2e

- [ ] **Step 1: Full test + build**

Run: `swift test && swift build`
Expected: all unit tests PASS; app builds clean.

- [ ] **Step 2: Owner GUI e2e** (hands-on, Accessibility granted; run as the debug-identity build)

Verify and check off each:
- [ ] **Settings migration:** upgrade over an install that has `launchAtLogin`/`showInMenuBar` set to non-defaults → both survive; gap = 0, snap = on.
- [ ] **Gaps:** set gap = 12 → keyboard halves/quarters/thirds/fullscreen show a 12pt outer margin and 12pt between two tiled windows; center and make-larger/smaller are unaffected; "skip top gap" removes only the top margin.
- [ ] **Cycling still works** with a non-zero gap (½→⅔→⅓ on repeated left-half).
- [ ] **Drag-snap zones:** top→maximize, four corners→quarters, left/right middle→halves, left/right near a corner→top/bottom half, bottom thirds→first/center/last with drag-toward-center→two-thirds.
- [ ] **Footprint** appears/reframes/disappears correctly and matches the final placement (incl. gap).
- [ ] **Undo** (⌘Z / the Undo hot key) reverts a drag-snap.
- [ ] **Unsnap-restore:** grabbing a snapped window shrinks it back under the cursor.
- [ ] **Multi-display:** dragging to an edge on a secondary display snaps on that display.
- [ ] **Toggle off** in Settings → dragging no longer snaps; toggle on → it resumes without relaunch.
- [ ] **Startup:** hot keys work after launch; launch-at-login still persists across a toggle.

- [ ] **Step 3: Tag/PR** per the project's release flow (branch → PR → squash-merge to `main` → tag `vX.Y.Z`). Out of scope for this plan beyond noting it.

---

## Self-Review (completed while authoring)

- **Spec coverage:** Feature A → Tasks A1–A7. Feature B → B1–B2. Feature C → C1–C7 (+ verify).
  Bottom-edge thirds + two-thirds promotion → C1/C2/C6. Unsnap-restore → C6. Gaps↔snap composition
  → C1 uses `WindowGap`. Migration gotcha → A5. Dropped #7/#11 → not in plan (by decision).
- **Placeholders:** none. Two spots flag *expected-value refinement after running the test* (A3, C1
  `floor` rounding) with the exact arithmetic and the behavioral guard that must hold — this is a
  real TDD refinement step, not a placeholder. One typo-guard note in C7 tells the implementer the
  clean form to use.
- **Type consistency:** `WindowGap(size:skipTopEdge:)`, `SnapTarget`, `SnapGeometry.rect/zone/
  sideEdgeHalf/bottomEdgeThird`, `SnapZone`, `ThirdColumn`, `WindowActionController.windowUnderCursor/
  frame/apply`, `AccessibilityElement.windowUnderCursor(atCocoaPoint:)`, and the two notification
  names are used consistently across tasks. `resolve(...)` keeps `history` trailing.
- **Known simplifications (surfaced, not hidden):** drag-snap halves use plain `floor` splits (C1
  note); unsnap-restore is lighter than Rectangle's last-action bookkeeping (C6 note). Both isolated
  and revisit-able after e2e.
