# Spectacle 2 — Window-Action Engine Design

- **Date:** 2026-07-06 (rev. 2 — review fixes)
- **Status:** Proposed (awaiting final review)
- **Branch:** `rewrite/dragonkit-swift6`
- **Scope:** The keyboard-driven window mover/resizer that is the point of the app. This spec
  covers the **engine only**. The DragonKit menu-bar shell and all release/packaging concerns
  are tracked in §12 (not this spec).

## 1. Goals & non-goals

**Goals**
- Reimplement Spectacle's **18 window actions** with **full behavior parity** (confirmed
  decision), including the signature ½→⅔→⅓ repeat-press cycling and six-region thirds cycling.
- Every action bound to a **user-configurable global shortcut**, shipping Spectacle's classic
  defaults.
- Modern, public APIs only: Accessibility (AX) for window control, Carbon
  `RegisterEventHotKey` for global hotkeys. No private CGS/window-server calls.
- The parity-critical geometry is **pure, deterministic, and fully unit-tested**.

**Non-goals (v1 — YAGNI guard)**
- No window gaps/padding, custom fractions, drag-to-snap, layout presets, or per-app rules.
- No Mac App Store build (Accessibility control requires non-sandboxed; keep the core cleanly
  separable so a sandbox-viable subset *could* become a MAS target later, but do not design
  for it now).

## 2. The 18 actions and default shortcuts

16 **geometry** actions + 2 **history** actions (Undo/Redo). All 18 are bound to a shortcut.

| Action | Default | Action | Default |
|---|---|---|---|
| Center | ⌥⌘C | Fullscreen | ⌥⌘F |
| Left Half | ⌥⌘← | Right Half | ⌥⌘→ |
| Top Half | ⌥⌘↑ | Bottom Half | ⌥⌘↓ |
| Upper Left | ⌃⌘← | Lower Left | ⌃⇧⌘← |
| Upper Right | ⌃⌘→ | Lower Right | ⌃⇧⌘→ |
| Next Third | ⌃⌥→ | Previous Third | ⌃⌥← |
| Next Display | ⌃⌥⌘→ | Previous Display | ⌃⌥⌘← |
| Make Larger | ⌃⌥⇧→ | Make Smaller | ⌃⌥⇧← |
| Undo Last Move | ⌥⌘Z | Redo Last Move | ⌥⌘⇧Z |

## 3. Architecture — pure core + thin adapters

Three SwiftPM targets:

```
Spectacle2 (executableTarget)  ──depends──▶  SpectacleCore (library, pure)
   AccessibilityElement                          WindowAction
   ScreenProvider                                WindowCalculator
   HotKeyManager (Carbon)                        WindowGeometry helpers
   WindowActionController (@MainActor)           WindowHistory
   ShortcutStore + ShortcutsPane (SwiftUI)       Shortcut + ModifierFlags (neutral)
                                              ▲
                          SpectacleCoreTests ─┘  (swift-testing)
```

- **`SpectacleCore`** depends only on Foundation/CoreGraphics (`CGRect`, `CGFloat`). **No AppKit,
  no AX, no Carbon, no `NSScreen`.** This is what makes it testable and MAS-separable.
- **`Spectacle2`** owns everything platform-specific and the UI. It already depends on
  DragonKit + DragonKitUpdates; it adds a dependency on `SpectacleCore`.
- **`SpectacleCoreTests`** covers `SpectacleCore` exhaustively.

### Coordinate convention (the one tricky thing, isolated) — see §5.1 for the exact formula

All `SpectacleCore` math is done in **Cocoa bottom-left–origin coordinates** — the same space
`NSScreen.visibleFrame` uses and the same space the original Spectacle JavaScript used (in it,
"upper" = larger `y`). The **only** AX↔Cocoa Y-flip lives in `AccessibilityElement`. The core
never sees AX coordinates.

## 4. SpectacleCore (pure — implemented test-first)

### 4.1 `WindowAction`
```swift
enum WindowAction: String, CaseIterable, Codable, Sendable {
    case center, fullscreen
    case leftHalf, rightHalf, topHalf, bottomHalf
    case upperLeft, upperRight, lowerLeft, lowerRight
    case nextThird, previousThird
    case nextDisplay, previousDisplay
    case makeLarger, makeSmaller
    case undo, redo
}
```
`center … makeSmaller` (16) are *geometry* actions computed by `WindowCalculator`. `undo`/`redo`
are *history* actions handled by `WindowActionController` via `WindowHistory` (no geometry).

### 4.2 `WindowCalculator`
Input mirrors the original signature:
```swift
struct CalculationInput {
    var windowRect: CGRect                  // current window, Cocoa coords
    var sourceVisibleFrame: CGRect          // visibleFrame of the window's current screen
    var destinationVisibleFrame: CGRect     // == source for same-screen actions
}
func calculate(_ action: WindowAction, _ input: CalculationInput) -> CGRect?
```
Returns the new window rect, or `nil` for a no-op (e.g. size below minimum; or if given a
history action, which it does not handle). Each geometry case is a **1:1 port of the
corresponding original JavaScriptCore file** (kept in git history on `master` under
`Spectacle/Resources/Window Position Calculations/`). Exact semantics:

**Shared helpers**
- `rectCenteredWithin(container:win:)` → `container.contains(win)` AND `|midX(container)−midX(win)| ≤ 1` AND `|midY(container)−midY(win)| ≤ 1`.
- `rectFitsWithin(win:screen:)` → `win.width ≤ screen.width && win.height ≤ screen.height`.

**Halves** (Left/Right/Top/Bottom) — each ported from its own JS file; the pattern (Left Half):
- Base = visible frame with `width = floor(frame.width/2)`, left-aligned (`x = frame.x`), full height.
- **Repeat-press cycle** only when the window is already centered on the base axis
  (`|midY(win) − midY(base)| ≤ 1` for L/R; `|midX …|` for T/B):
  - if `rectCenteredWithin(base, win)` → return the ⅔ rect (`width = floor(frame.width*2/3)`, same alignment);
  - else if `rectCenteredWithin(twoThird, win)` → return the ⅓ rect (`width = floor(frame.width/3)`);
  - otherwise return the ½ base. → cycle ½ → ⅔ → ⅓ → ½.
  Right/Top/Bottom are the axis/edge-mirrored versions (right-aligned; top uses larger `y`; the
  cycle acts on width for L/R and on height for T/B).

**Corners** (Upper/Lower Left/Right) — ported per file; pattern (Upper Left):
- Quarter rect: `width = floor(frame.width/2)`, `height = floor(frame.height/2)`;
  Upper → `y = frame.y + floor(frame.height/2) + (frame.height mod 2)`; left → `x = frame.x`.
- Repeat-press cycle acts on **width only** (keeping the quarter's height and top/bottom edge):
  quarter-width(½) → ⅔-width → ⅓-width → back, guarded by the same centered-on-axis test.

**Center** — keep size, center in frame: `x = round((frame.width−win.width)/2)+frame.x`,
`y = round((frame.height−win.height)/2)+frame.y`.

**Fullscreen** — window = visible frame.

**Make Larger / Smaller** — symmetric ±30 pt (`sizeOffset = +30` / `−30`), ported from
`SpectacleWindowSizeAdjuster`:
1. `width += offset; x −= floor(offset/2)`, then snap against left/right edges the window was
   already touching (within 5 pt), clamp width to frame width.
2. `height += offset; y −= floor(offset/2)`, then snap against top/bottom edges, clamp height to
   frame height (and reset `y` to original if height hit the frame).
3. If the window was against **all four** edges and shrinking, shrink symmetrically instead.
4. **Minimum:** if the result’s width ≤ `floor(frame.width/4)` or height ≤ `floor(frame.height/4)`,
   return the original rect (no-op). "Against an edge" = gap ≤ 5 pt.

**Next / Previous Third** — build six regions from the destination frame: three ⅓-width columns
(left→right, full height) then three ⅓-height rows (top→bottom, full width). Find the region the
window is `rectCenteredWithin`; return the next (Next) / previous (Previous) with wraparound. If
the window matches no region, return the first region (left column).

**Next / Previous Display** — if `rectFitsWithin(win, destination)` → center the window (keep
size) in the destination frame; else → return the destination frame (fill). The source/dest
frames are chosen by the app-side `ScreenProvider`; the core only does fit-or-fill.

### 4.3 `WindowHistory`
```swift
struct WindowHistory {                       // value type, per-window stacks
    mutating func record(_ frame: CGRect, for id: WindowID)   // push undo, clear redo
    mutating func undo(current: CGRect, for id: WindowID) -> CGRect?
    mutating func redo(current: CGRect, for id: WindowID) -> CGRect?
}
```
Standard undo/redo:
- `record` is called by the controller **only for geometry moves** (never for undo/redo). It
  pushes the pre-move frame onto the window's undo stack and clears its redo stack.
- `undo` pops the undo stack, pushes the given `current` frame onto the redo stack, returns the
  restored frame (or `nil` if the undo stack is empty).
- `redo` pops the redo stack, pushes `current` onto the undo stack, returns the frame (or `nil`).

`WindowID` is an opaque `Hashable` supplied by the app (see §5.1). The generic core has no
knowledge of how identity is derived. Empty stack → `nil` (no-op).

## 5. Spectacle2 adapters (thin — verified by running the app)

### 5.1 `AccessibilityElement` (owns the coordinate flip + window identity)
- Resolves the frontmost app's focused window: `NSWorkspace.shared.frontmostApplication.pid`
  → `AXUIElementCreateApplication(pid)` → `kAXFocusedWindowAttribute`.
- `frame() -> CGRect?` reads `kAXPositionAttribute` (top-left origin) + `kAXSizeAttribute` and
  converts **AX → Cocoa**; `setFrame(_:)` converts **Cocoa → AX** and writes size then position.
- **Exact global conversion.** Anchor on the primary screen — `NSScreen.screens[0]` (the
  menu-bar screen, fixed at Cocoa origin `(0,0)`); *not* `NSScreen.main` (which follows key
  focus). Let `H = NSScreen.screens[0].frame.height` (full `frame`, not `visibleFrame`). For a
  window of height `h`:
  - AX→Cocoa: `cocoa.x = ax.x`, `cocoa.y = H − ax.y − h`
  - Cocoa→AX: `ax.x = cocoa.x`, `ax.y = H − cocoa.y − h`
  This is correct globally — including displays with negative origins and displays above/below
  the primary — because both coordinate systems share the primary-screen anchor and differ only
  by a flip about the primary screen's top edge. (A window above the menu-bar screen has
  negative `ax.y` → `cocoa.y > H`; a window below has `ax.y > H` → `cocoa.y < 0`.)
- **`windowID`** — a concrete `struct WindowID: Hashable` that wraps the focused-window
  `AXUIElement`, with `==`/`hash(into:)` implemented via `CFEqual`/`CFHash`. AX returns
  CFEqual-equal element refs for the same on-screen window across calls, so this is a stable
  public-API identity for the lifetime of that window. (Limitation, acceptable: closing and
  reopening a window yields a new id; window history is transient and per-session anyway.)
- Any AX failure (no frontmost app, no focused window, non-settable position/size) → `frame()`
  returns `nil` and `setFrame` is a no-op.

### 5.2 `ScreenProvider`
- `screenContaining(_ cocoaRect:) -> NSScreen` — the `NSScreen` whose `.frame` contains the
  window's Cocoa center (fallback `NSScreen.main`), giving `sourceVisibleFrame`.
- `displayCycle(from:direction:)` — orders `NSScreen.screens` (by `frame.minX`, then `minY`) and
  returns the next/previous screen's `visibleFrame` as the `destinationVisibleFrame`. Same-screen
  actions use destination == source.

### 5.3 `HotKeyManager` (owns all Carbon)
- Wraps Carbon `RegisterEventHotKey`; **translates the core's neutral `ModifierFlags` into Carbon
  modifier masks** (`cmdKey`/`optionKey`/`controlKey`/`shiftKey`) here — Carbon never leaks into
  the core.
- Registers one hot key per bound action from the shortcut map, installs a single Carbon event
  handler that maps the fired `EventHotKeyID` back to a `WindowAction` and calls the controller,
  and re-registers when the map changes. Surfaces registration failures (key already taken) so
  the Shortcuts UI can flag conflicts.

### 5.4 `WindowActionController` (`@MainActor`) — the orchestrator
On a triggered action:
1. **Gate:** if `!AXIsProcessTrusted()` → no-op (the Permissions pane is the surface).
2. Get the focused window `frame` + `WindowID` (else no-op).
3. Resolve `sourceVisibleFrame` / `destinationVisibleFrame` from `ScreenProvider`.
4. **History actions** (`undo`/`redo`): ask `WindowHistory.undo/redo(current: frame, for: id)`;
   if it returns a frame, `setFrame` it. **Do not call `record`** — history already advanced.
5. **Geometry actions:** `WindowCalculator.calculate(action, input)`; if it returns a rect,
   `record(frame, for: id)` (the *pre-move* frame) **then** `setFrame(newRect)`.

This split is the fix for the redo-clobbering bug: only step 5 records; step 4 never does.

## 6. Settings

- **`ModifierFlags`** (in `SpectacleCore`) — a neutral `OptionSet` (`.command`, `.option`,
  `.control`, `.shift`), independent of Carbon/AppKit. `Codable`/`Sendable`.
- **`Shortcut`** (in `SpectacleCore`) — `struct { keyCode: UInt16; modifiers: ModifierFlags }`,
  `Codable`/`Equatable`/`Sendable`, with a **pure display string** builder (`⌥⌘←`). It contains
  **no Carbon**; the Carbon mask translation lives in `HotKeyManager` (§5.3). Display formatting
  is unit-tested in the core.
- **`ShortcutStore`** — `DragonSettingsStore<ShortcutMap>` where `ShortcutMap` is a
  `Codable [WindowAction: Shortcut]`, defaulting to the classic bindings in §2. Persisted in the
  existing settings suite `com.dragonapp.spectacle-2.settings` so Backup & Restore captures it.
- **`ShortcutsPane: SettingsPane`** — id `"shortcuts"`, sits **between General and Permissions**
  in the sidebar. A `DragonForm` with `DragonSection`s grouping the actions; each row shows the
  action name and an in-app **recorder** to view/rebind/clear its shortcut, with
  `.dragonAnnotation` for conflict/hint text. Rebinding writes `ShortcutStore` and asks
  `HotKeyManager` to re-register. A "Restore Defaults" affordance resets the map.

## 7. Error handling

Every failure path is a **silent no-op**, by design:
- Accessibility not granted → no-op; the Permissions pane shows live status + "Open System
  Settings" and is the only place that explains it.
- No frontmost app / no focused or non-resizable window → no-op.
- `WindowCalculator` returns `nil` (size below minimum) → no-op.
- Undo/redo with an empty stack → no-op.
No beeps, alerts, or notifications in v1.

## 8. Testing strategy (TDD)

`SpectacleCore` is pure, so tests come **first** (swift-testing, `import Testing`), then
implement to green. Fixed fixtures use realistic frames, e.g. a `1440×900` visible frame at
origin `(0,0)` and a menu-bar-inset frame, plus a two-screen layout. Cases:
- Each half & corner: base result; then the **repeat sequence** ½→⅔→⅓→½ (feeding each output
  back as the next input) asserting exact rects.
- Center (odd/even deltas), Fullscreen.
- Make Larger/Smaller: growth, symmetric shrink, edge-snap retention, clamp to frame, and the
  ¼-screen **minimum no-op**.
- Next/Previous Third: full six-region cycle with wraparound, and the "uncentered → left column"
  default.
- Next/Previous Display: fit→centered, oversized→fill.
- `WindowHistory`: record/undo/redo across multiple windows; empty-stack no-ops; redo cleared by
  a new record; **and the controller invariant that undo/redo never call record** (asserted via
  a sequence: move → move → undo → redo returns to the second move, not the first).
- `Shortcut` display formatting; `ModifierFlags` round-trip.

Adapters (`AccessibilityElement`, `ScreenProvider`, `HotKeyManager`) are deliberately thin and
side-effectful; they're verified by building and running (`scripts/run.sh`), not unit tests.

## 9. Build order (informs the implementation plan)

1. Add `SpectacleCore` library target + `SpectacleCoreTests`; wire `Spectacle2` to depend on it.
2. TDD `WindowAction`, geometry helpers, and each `WindowCalculator` action (port from the JS in
   git history), then `WindowHistory`, then `ModifierFlags`/`Shortcut`.
3. Adapters: `AccessibilityElement` (incl. coordinate flip + `WindowID`), `ScreenProvider`,
   `HotKeyManager`, `WindowActionController`.
4. `ShortcutStore` (+ default map) and `ShortcutsPane`; wire into the settings sidebar and the
   `HotKeyManager`.
5. Run end-to-end; confirm each shortcut moves the frontmost window correctly across one and two
   displays; confirm undo/redo.

## 10. DragonKit note

If an in-app **shortcut recorder** proves generally useful, flag it for DragonKit (a shared
`ShortcutRecorder`/`KeyboardShortcut` component) rather than keeping it app-private — per the
"add it to DragonKit and consume" rule. Decide after the app-side recorder exists.

## 11. Assumptions

- macOS 26 baseline, must also run on macOS 27; Apple Silicon only (arm64).
- Carbon `RegisterEventHotKey` remains available and is the reliable global-hotkey path.
- A single focused-window target per action (Spectacle's model); no multi-window batch ops.

## 12. Work outside this spec (whole-app — separate spec/plan coverage)

This spec is the **engine**. The following parts of the original request are **not** covered here
and need their own tracking. Current status noted:

- **DragonKit shell** — *done* (scaffolded, builds, runs): Settings/About/What's New/Permissions/
  Backup/Updates/Uninstall, menu-bar wiring, live localization plumbing.
- **Debug identity + run.sh** — *done* (`com.dragonapp.spectacle-2.debug` / "Spectacle 2 Debug").
- **Git process** — *in progress*: branch `rewrite/dragonkit-swift6`, do-not-push until owner
  confirms; ObjC tree removed as one commit.
- **Localization completeness** — *partial*: shell strings translated in 7 languages; the new
  Shortcuts pane strings (action names, hints, "Restore Defaults") must be added in all 7.
- **Release wiring** — *todo*: `vX.Y.Z` tag → shared `dragon-release-ci` reusable workflow
  (`build_kind: swiftpm`, `app_slug: spectacle-2`, `swiftpm_product_name: Spectacle2`, …),
  Developer ID sign + notarize (arm64), GitHub Release, signed Sparkle appcast, Homebrew cask bump.
- **Sparkle** — *todo*: generate a NEW EdDSA key pair (do not reuse another app's); public key →
  `SUPublicEDKey`, private key → CI secret; self-host `docs/appcast.xml` via raw.githubusercontent.
- **Homebrew cask** — *todo*: `teddychan/tap/spectacle-2`.
- **MAS** — *deferred / open question* (sandbox vs. cross-app AX); do not design for it.

Each todo item should get its own short spec/plan before implementation.
