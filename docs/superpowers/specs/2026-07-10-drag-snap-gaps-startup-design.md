# Spectacle 2 — Drag-Snap, Window Gaps & Startup Deferral Design

- **Date:** 2026-07-10
- **Status:** Proposed (awaiting user review)
- **Branch:** `claude/spectacle-2-roadmap-5f5ddb` (worktree)
- **Scope:** Three independent enhancements to the shipped v2.0.4 app:
  - **A. Window gaps** — configurable padding at screen edges and between tiled windows.
  - **B. Startup deferral** — move hot-key registration and login-item reconcile off the launch critical path.
  - **C. Drag-to-edge snapping** — Rectangle-parity drag snapping.
- **Explicitly dropped from the original request:** #7 (mixed-DPI Y-flip) and #11 (cycling
  micro-opt). Investigation showed the Y-flip in `AccessibilityElement` is already coordinate-correct
  (anchored on the primary/AX-origin display; math is in points so backing scale is irrelevant),
  and the ½→⅔→⅓ cycling detection is pure in-memory geometry with zero extra AX round-trips.
  Neither is a real defect; both are dropped to avoid manufactured work.

## 1. Goals & non-goals

**Goals**
- Ship drag-to-edge snapping that **matches Rectangle's default out-of-box behavior**, so users
  with Rectangle muscle memory feel at home.
- Add a single configurable **gap** applied consistently to keyboard actions and drag-snaps.
- Trim the synchronous launch path without changing observable behavior.
- Keep the parity-critical geometry **pure and unit-tested** in `SpectacleCore`; keep AppKit/AX/Carbon
  glue in the app layer (verified by owner GUI e2e, per the project's established pattern — AppKit and
  Carbon are not headlessly testable).

**Non-goals (v1 — YAGNI guard; confirmed with owner)**
- No Mission-Control-dragging CGEventTap mode (Rectangle's default is the passive NSEvent monitor;
  we ship only that).
- No snap-modifier requirement, haptic feedback, footprint fade/grow animation, per-zone remapping UI,
  portrait-orientation zone maps, or per-app ignore list. These are advanced Rectangle toggles that do
  not change the default feel.
- No separate "edge gap" vs "between-window gap" values — one gap value (plus a `skipGapTopEdge` flag,
  matching Rectangle).
- No Mac App Store target (drag-snap + AX control require a non-sandboxed build).

---

## 2. Feature A — Window gaps

### 2.1 Behavior
A single `gap` value (points, default **0** → behavior identical to today). Applied as an **outer
margin** at screen edges **and** as spacing **between adjacent tiled windows**, for:
- Halves, corners (quarters), thirds, fullscreen.

**Not** applied to: **Center** and **Make Larger / Make Smaller** (they preserve the window's own
size — insetting them would be surprising). `WindowSizeAdjuster` clamping stays relative to the
un-inset `visibleFrame`, so growing a window still fills to the real screen edge.

A `skipGapTopEdge` flag (default **false**) suppresses the gap on the top edge only (parity with
Rectangle's `skipGapTopEdge`), useful when the menu bar already provides visual separation.

### 2.2 Gap math (the "half-gap" model)
To get a full gap `G` on outer edges **and** between neighbors with one value, apply a half-gap
twice:
1. Inset the working `visibleFrame` by `G/2` on each edge (skip the top edge if `skipGapTopEdge`).
2. Compute the half/corner/third/fullscreen rect within that working frame as today.
3. Inset the **resulting** rect by `G/2` on each edge (skip top edge accordingly).

Result: outer edges get `G/2 + G/2 = G`; two adjacent tiles get `G/2 + G/2 = G` between them.
Fullscreen ends up with a uniform `G` margin. Center and resize skip step 1 and 3 entirely.

### 2.3 Where it lives (single chokepoint)
`SpectacleCore` stays the source of truth.
- Add `gap: CGFloat = 0` and `skipGapTopEdge: Bool = false` to `CalculationInput`
  (`WindowCalculator.swift`). Defaults keep every existing call site and unit test unchanged.
- `WindowCalculator.calculate` performs step 1 (inset `frame`) at the point it reads
  `destinationVisibleFrame`, and step 3 (inset the result) on the computed rect for the
  gap-applicable actions only. Center / make-larger / make-smaller bypass both.
- The positional-thirds helpers (see §4.3) are gap-aware for free because they build off the same
  working frame.

### 2.4 Settings & UI
- Add `gap: Double = 0` and `skipGapTopEdge: Bool = false` to `AppSettings` (`SettingsModel.swift`).
- `GeneralPane`: a new section "Window gaps" with a stepper/field ("Gap between windows", pt) and a
  "Skip gap at top edge" toggle. Localized in all 7 languages.

### 2.5 Tests (SpectacleCoreTests)
- `gap = 0` reproduces every current result exactly (regression guard against existing tests).
- `gap = N`: left/right/top/bottom halves, four corners, thirds, and fullscreen produce the expected
  inset rects (outer margin N, inter-window spacing N).
- Center and make-larger/smaller are **unchanged** when `gap = N`.
- `skipGapTopEdge = true`: no inset on the top edge; other edges unaffected.

---

## 3. Feature B — Startup deferral

### 3.1 Behavior
No observable change — the app just returns from `applicationDidFinishLaunching` faster.

### 3.2 Changes
- **Hot-key registration:** today `windowActions.start(...)` synchronously loops all 18
  `WindowAction`s calling `RegisterEventHotKey` on the main thread inside
  `applicationDidFinishLaunching` (`AppDelegate.swift`). Move the registration to the next main-runloop
  tick (`DispatchQueue.main.async` / a `Task { @MainActor }`) so it no longer blocks launch. The Carbon
  event handler is installed the same way; a hot key pressed in the first few ms simply won't fire —
  acceptable.
- **Login-item reconcile:** `SettingsModel.init` calls `LoginItem.setEnabled(...)` synchronously
  (an `SMAppService` status + register/unregister). Move this reconcile off the init critical path
  (run it once after launch, `@MainActor` async). The persisted preference is unchanged; only the OS
  reconcile is deferred.

### 3.3 Success criterion / verification
Neither hot-key registration nor the login-item reconcile blocks `applicationDidFinishLaunching`
returning; hot keys still work once the app is idle, and the login-item state still reconciles on
launch. Verified by owner GUI e2e (launch, confirm every hot key fires; toggle launch-at-login and
confirm it persists). This is a small, isolated change and can land independently of A and C.

---

## 4. Feature C — Drag-to-edge snapping (Rectangle-parity)

Behavior mirrors Rectangle's **default** configuration. Source references below cite Rectangle
(`rxhanson/Rectangle`, `Rectangle/Snapping/…`) for parity.

### 4.1 Engine
New `@MainActor final class DragSnapController` in `Sources/Spectacle2/`, owned by `AppDelegate`.
Active only when the feature toggle is **on** and Accessibility is granted.

- **Event source (Rectangle "Passive" default):** `NSEvent` local **and** global monitors for
  `.leftMouseDown`, `.leftMouseUp`, `.leftMouseDragged`.
- **Target acquisition:** on `.leftMouseDown`, resolve the window under the cursor via
  `AXUIElementCopyElementAtPosition` on the system-wide element, walk up to the window element,
  capture its `WindowID` (reusing the existing `WindowID` CFEqual/CFHash type) and initial frame.
  Live frame re-read from AX on each drag event.
- **Arming:** snapping arms on the **first real move** — origin changed **and** size unchanged
  (a resize never snaps). Footprint/zone detection runs only while a move is in progress.

### 4.2 Zone geometry & map
Constants (Rectangle defaults): edge margin **5 pt**, corner catch box **20 pt** (≈25 pt corner
band), short-edge sub-zone **145 pt**. Cursor is tested against each screen's **frame**, looping
**all** `NSScreen.screens`; the target rect is computed against **that** screen's `visibleFrame`.
No special-casing of inner shared edges vs. the outer desktop perimeter (parity with Rectangle:
the seam between two displays is a live zone for whichever screen wins the loop).

Default landscape zone → action (Rectangle `SnapAreaModel.defaultLandscape`):

| Zone | Action |
|---|---|
| Top edge | Maximize (fullscreen) |
| Top-left / top-right / bottom-left / bottom-right corner (25 pt) | Quarter (upperLeft / upperRight / lowerLeft / lowerRight) |
| Left edge — middle | Left half |
| Left edge — within 145 pt of top / bottom corner | Top half / Bottom half |
| Right edge — middle | Right half |
| Right edge — within 145 pt of top / bottom corner | Top half / Bottom half |
| Bottom edge | Thirds — see §4.3 |

Corner zones take priority over edges.

### 4.3 Bottom-edge thirds (full parity, confirmed in scope)
Rectangle splits the bottom edge into vertical thirds by cursor x: left third → **first third**,
middle → **center third**, right third → **last third**. **Two-thirds promotion:** if the *previous*
snap zone during this drag was already a third on that side and the cursor moves into the center third,
it promotes to **first-two-thirds** / **last-two-thirds**.

Spectacle 2 exposes only `nextThird`/`previousThird` as public `WindowAction`s, but the positional
column math already exists inside `WindowCalculator.thirds()`. Plan:
- Add pure, gap-aware helpers in `SpectacleCore` returning the positional rects — first/center/last
  third and first-two-thirds/last-two-thirds — built off the same working frame as §2.2. Unit-tested.
- `DragSnapController` tracks the previous zone within the current drag to drive the two-thirds
  promotion, then calls the positional helper directly (these are drag-only snap targets, not new
  bindable keyboard actions).

### 4.4 Footprint preview
New borderless translucent overlay window `SnapPreviewOverlay` (an `NSWindow`, `level = .modalPanel`,
`isOpaque = false`, `hasShadow = false`, `.transient` collection behavior):
- Fill black @ **0.3** alpha, border `.lightGray` **2 pt**, corner radius **16** on macOS 26+.
- Shows the **exact target rect including gaps** (computed via the same `WindowCalculator` path).
- Orders front on entering a zone, re-frames when the zone changes, orders out when the cursor leaves
  all zones. No fade/grow animation in v1 (Rectangle's default multiplier is 0 anyway).

### 4.5 Drop
On `.leftMouseUp` while a zone is active: compute the target rect via `WindowCalculator` (with the
current gap), `ax.setFrame(...)` on the captured window, hide the overlay, and **record into
`WindowHistory`** so **undo works on drag-snaps** (parity with Rectangle recording drag-snaps in its
action history). Fast-drag fallback: if no zone was tracked but the window's origin moved with
unchanged size, re-check the zone under the cursor at mouse-up and snap anyway.

### 4.6 Unsnap-restore (Rectangle default-on)
The moment a move is detected on a window that is currently at its last-snapped frame **and** has a
recorded restore rect, restore its **pre-snap size mid-drag**, keeping it under the cursor (preserve
`maxX` if it fits, else recenter horizontally on the cursor), then clear the last action. Otherwise,
record the current frame as the restore rect for a future un-snap. State is held per `WindowID` in the
controller (a small restore-rect map alongside the existing `WindowHistory`).

### 4.7 Settings & UI
- `AppSettings`: `dragSnapEnabled: Bool = true` (Rectangle ships snapping on; default on for parity).
- `GeneralPane`: toggle "Snap windows dragged to screen edges". Localized ×7.
- Feature respects the Accessibility gate already used by hot keys; if permission is missing, the
  monitors are not installed.

### 4.8 Tests
- **Pure (SpectacleCoreTests):** positional-thirds helpers (§4.3) and their gap-aware insets; the
  zone-classification function — given a cursor point + screen frame + the constants, it returns the
  correct `Directional`/action (this logic is extracted as a pure function so it *is* unit-testable,
  independent of NSEvent).
- **Not headlessly testable (owner GUI e2e):** the NSEvent monitors, AX under-cursor acquisition,
  overlay rendering, unsnap-restore feel, multi-display drag.

---

## 5. Build order, isolation & delivery

Three independent units; shared touch-points (`AppSettings`, `GeneralPane`) are small and additive.

1. **A — gaps in `SpectacleCore` + settings/UI.** Pure and tested; C depends on it for correct snap
   frames. Foundation.
2. **B — startup deferral.** Fully isolated; can land anytime.
3. **C — drag-snap.** Largest; builds on A. Extract the zone-classification and positional-thirds as
   pure functions so the geometry is unit-tested; keep NSEvent/AX/overlay glue thin.

Each unit is a separate commit (and can be a separate PR). Subagents can drive A and B in parallel
(they don't conflict beyond the additive `AppSettings`/`GeneralPane` edits, which will be sequenced or
merged carefully); C follows A.

## 6. Risks / open questions
- **AX under-cursor acquisition reliability** varies by app; Rectangle has retry logic (≤20 attempts,
  ≥0.1s apart) — we replicate a modest retry.
- **Global NSEvent monitors** require the app to be running with Accessibility trust (already granted
  for hot keys); no new entitlement.
- **`AppSettings` migration (must-handle):** `DragonSettingsStore.load()` uses `try?` and returns
  `defaultValue` on **any** decode error, and Swift's *synthesized* `Decodable` throws `keyNotFound`
  for missing keys (it does **not** apply property-initializer defaults). So naively adding `gap`,
  `skipGapTopEdge`, and `dragSnapEnabled` would make every existing user's stored JSON fail to decode
  and silently reset **all** settings (including `launchAtLogin` / `showInMenuBar`). **Fix:** give
  `AppSettings` a hand-written `init(from decoder:)` that decodes each field with
  `decodeIfPresent(...) ?? <default>`, so old payloads decode cleanly and new fields take their
  defaults (gap 0, skipGapTopEdge false, dragSnapEnabled true). Add a decode test with a legacy
  two-field JSON blob asserting the old values survive and the new fields default.
