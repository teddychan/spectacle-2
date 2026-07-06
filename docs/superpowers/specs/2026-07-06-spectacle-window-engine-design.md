# Spectacle 2 — Window-Action Engine Design

- **Date:** 2026-07-06
- **Status:** Proposed (awaiting review)
- **Branch:** `rewrite/dragonkit-swift6`
- **Scope:** The keyboard-driven window mover/resizer that is the point of the app. The
  DragonKit menu-bar shell (Settings, About, What's New, Permissions, Backup, Updates,
  Uninstall, localization) is already scaffolded and out of scope here.

## 1. Goals & non-goals

**Goals**
- Reimplement Spectacle's 20 window actions with **full behavior parity** (confirmed decision),
  including the signature ½→⅔→⅓ repeat-press cycling and the six-region thirds cycling.
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

## 2. The 20 actions and default shortcuts

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
   ShortcutStore + ShortcutsPane (SwiftUI)       Shortcut (model)
                                              ▲
                          SpectacleCoreTests ─┘  (swift-testing)
```

- **`SpectacleCore`** depends only on Foundation/CoreGraphics (`CGRect`, `CGFloat`). No AppKit,
  no AX, no Carbon, no `NSScreen`. This is what makes it testable and MAS-separable.
- **`Spectacle2`** owns everything platform-specific and the UI. It already depends on
  DragonKit + DragonKitUpdates; it adds a dependency on `SpectacleCore`.
- **`SpectacleCoreTests`** covers `SpectacleCore` exhaustively.

### Coordinate convention (the one tricky thing, isolated)

All `SpectacleCore` math is done in **Cocoa bottom-left–origin coordinates** — the same space
`NSScreen.visibleFrame` uses and the same space the original Spectacle JavaScript used (in it,
"upper" = larger `y`). The **only** AX↔Cocoa Y-flip lives in `AccessibilityElement`, at the
boundary where AX (top-left origin, relative to the primary display) is read/written. The core
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
`center … makeSmaller` are *geometry* actions computed by `WindowCalculator`. `undo`/`redo` are
*history* actions handled by `WindowActionController` via `WindowHistory` (no geometry).

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
Returns the new window rect, or `nil` for a no-op (e.g. size below minimum, or a history
action). Each case is a **1:1 port of the corresponding original JavaScriptCore file** (kept in
git history on `master` under `Spectacle/Resources/Window Position Calculations/`). Exact
semantics:

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
Standard undo/redo: `record` (called on every successful geometry move) pushes the pre-move
frame onto the window's undo stack and clears its redo stack; `undo` pops the undo stack, pushes
the current frame to redo, returns the restored frame; `redo` is the mirror. `WindowID` is an
opaque `Hashable` the app supplies (see §5). Empty stack → `nil` (no-op).

## 5. Spectacle2 adapters (thin — verified by running the app)

- **`AccessibilityElement`** — resolves the frontmost app's focused window via
  `AXUIElementCreateApplication(frontmost.pid)` → `kAXFocusedWindowAttribute`.
  `frame() -> CGRect?` reads `kAXPositionAttribute`/`kAXSizeAttribute` and **flips AX→Cocoa**
  using the primary display height; `setFrame(_:)` flips Cocoa→AX and writes size then position.
  `windowID` derives the `WindowID` (pid + `kAXWindowAttribute` identity) for history. Any AX
  failure → returns `nil` / no-ops.
- **`ScreenProvider`** — `screensOrderedForCycling()` from `NSScreen.screens`; given the window's
  current screen, yields `sourceVisibleFrame` and the next/previous `destinationVisibleFrame`
  for display actions. Same-screen actions use source == destination.
- **`HotKeyManager`** — wraps Carbon `RegisterEventHotKey`; registers one hot key per bound
  action from the shortcut map, installs a single `EventHotKeyID` handler that dispatches to the
  `WindowActionController`, and re-registers when the map changes. Reports registration failures
  (e.g. a key already taken by the system) so the Shortcuts UI can flag conflicts.
- **`WindowActionController`** (`@MainActor`) — the orchestrator. On a triggered action:
  1. gate: if `!AXIsProcessTrusted()` → no-op (Permissions pane is the surface);
  2. get focused window frame + `WindowID` (else no-op);
  3. resolve source/destination frames from `ScreenProvider`;
  4. `undo`/`redo` → `WindowHistory`; otherwise `WindowCalculator.calculate`;
  5. if a rect comes back, `record` the pre-move frame and `setFrame` the result.

## 6. Settings

- **`Shortcut`** — `struct { keyCode: UInt16; modifiers: UInt32 }`, `Codable`/`Equatable`/`Sendable`,
  with a display string (`⌥⌘←`) and conversion to Carbon modifier flags. Lives in `SpectacleCore`
  (pure, testable formatting) or the app as needed.
- **`ShortcutStore`** — `DragonSettingsStore<ShortcutMap>` where `ShortcutMap` is a
  `Codable [WindowAction: Shortcut]`, defaulting to the classic bindings in §2. Persisted in the
  existing settings suite `com.dragonapp.spectacle-2.settings` so Backup & Restore captures it.
- **`ShortcutsPane: SettingsPane`** — id `"shortcuts"`, sits **between General and Permissions**
  in the sidebar. A `DragonForm` with `DragonSection`s grouping the actions; each row shows the
  action name and an in-app **recorder** control to view/rebind/clear its shortcut, with
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
  a new record.
- `Shortcut` formatting and Carbon-modifier conversion.

Adapters (`AccessibilityElement`, `ScreenProvider`, `HotKeyManager`) are deliberately thin and
side-effectful; they're verified by building and running (`scripts/run.sh`), not unit tests.

## 9. Build order (informs the implementation plan)

1. Add `SpectacleCore` library target + `SpectacleCoreTests`; wire `Spectacle2` to depend on it.
2. TDD `WindowAction`, geometry helpers, and each `WindowCalculator` action (port from the JS in
   git history), then `WindowHistory`, then `Shortcut`.
3. Adapters: `AccessibilityElement`, `ScreenProvider`, `HotKeyManager`, `WindowActionController`.
4. `ShortcutStore` (+ default map) and `ShortcutsPane`; wire into the settings sidebar and the
   `HotKeyManager`.
5. Run end-to-end; confirm each shortcut moves the frontmost window correctly across one and two
   displays; confirm undo/redo.

## 10. DragonKit note

If an in-app **shortcut recorder** proves generally useful, flag it for DragonKit (a shared
`ShortcutRecorder`/`KeyboardShortcut` component) rather than keeping it app-private — per the
"add it to DragonKit and consume" rule. Decide after the app-side recorder exists and its shape
is known.
