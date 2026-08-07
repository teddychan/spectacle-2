# Changelog

All notable changes to Spectacle 2 are documented here. This project adheres to
[Semantic Versioning](https://semver.org/).

## [2.2.2] - 2026-08-07

**Nothing in this release changes how Spectacle 2 behaves.** It ships internal build-tooling
fixes and an explicit dependency pin. If you are on 2.2.1 there is no functional reason to
update.

### Changed
- The local development build now takes its display name from its own bundle rather than a
  hardcoded string, so a debug build no longer presents itself as the release build in the About
  panel, the Settings window title, or — the one that mattered — the Uninstall pane, whose
  optional-data path was resolving to the *release* build's `~/Library/Application Support`
  folder. In a release build this resolves to exactly the string it replaced, so the shipped app
  is unchanged.
- `scripts/run.sh` no longer quits an installed release copy every time it runs. Its process match
  was broad enough to hit `/Applications/Spectacle 2.app` as well as the debug build, because both
  bundles shipped an executable named `Spectacle2`. The debug bundle's executable is now named
  after the debug app, and the match is anchored to that bundle's own path.
- The debug build stamps its version as `X.Y.Z (Debug)`, so a screenshot or a bug report can't be
  mistaken for the release build.

### Internal
- DragonKit is now pinned to exactly `2.1.0` rather than floating with `from:`. `Package.resolved`
  is gitignored, so CI resolves dependencies from scratch on every build — a floating pin meant
  the next tag would silently ship whatever kit version happened to be newest at the time. Kit
  `2.2.0` is released and deliberately not taken in this release; it removes a Backup toggle and
  changes permission-refresh and uninstall behaviour, so it will get its own release once it has
  been tested hands-on. The kit's R10 conformance rule fails by design until then.

## [2.2.1] - 2026-08-06

A maintenance release. No new features — this is robustness and performance work on the
accessibility layer that every window action goes through, plus the first automated test coverage
for the app target.

### Fixed
- **An unresponsive app can no longer stall Spectacle 2.** Accessibility calls are synchronous
  cross-process IPC on the main thread, and they previously ran with the system default timeout, so
  a beachballing target application could hold up Spectacle 2's own menu bar and Settings window.
  All accessibility messaging is now bounded by an explicit 1-second timeout: past that, the action
  is a no-op instead of a freeze.
- **A misbehaving application can no longer crash Spectacle 2.** Values returned by the
  accessibility API were force-cast to the expected type. They now have their `CFTypeID` verified
  first, and an unexpected type makes the action a no-op.
- Removed a latent use-after-free in the global hot-key registration: the Carbon event handler held
  an unretained pointer to its manager and was never uninstalled. Not reachable in 2.2.0, since
  registration happens exactly once, but the guard is now in place.

### Changed
- **Drag-to-edge snapping no longer queries the dragged window on every mouse movement.** The frame
  read is only needed to tell a move from a resize when the drag arms, so once a drag is armed the
  snap path makes no accessibility calls at all.
- **Undo history is now capped at 50 positions per window** (previously one entry per move, kept
  for as long as the app ran). Anything older than the last 50 moves of a given window is no longer
  reachable with ⌥⌘Z — a deliberate trade for bounded memory in an app that stays resident.
- Drag-snap's pre-snap size memory is capped at 32 windows, evicting the oldest, so windows that
  were snapped and then closed no longer accumulate.

### Internal
- First tests for the `Spectacle2` app target: the persisted-settings migration decoder and the
  shortcut-store defaults merge, each against its own throwaway `UserDefaults` suite.
- The drag-snap zone-to-target decision moved into `SpectacleCore` as a pure function so it can be
  tested without a display. Test suite is 74 → 90.
- Documented in the README why Spectacle 2 ships without the App Sandbox: a sandboxed process
  cannot reach another application's windows through the accessibility APIs.

## [2.2.0] - 2026-08-04

Menu-bar dropdown changes inherited from **DragonKit 2.0**: every item now leads with an SF
Symbol, and **Uninstall** is gone from the menu — it lives in Settings.

### Added
- **Menu-bar icons** — every item in the dropdown now leads with an SF Symbol: About
  (`info.circle`), Check for Updates (`arrow.down.circle`), Settings (`gearshape`) and Quit
  (`power`). Supplied by the shared `DragonAppMenu`, so every Dragon app matches.

### Removed
- **Uninstall is no longer in the menu-bar dropdown**, where it sat one slip away from Quit. As a
  rare, destructive action it now lives only in Settings, as the last pane — which already
  confirms before removing anything and is otherwise unchanged.

### Changed
- DragonKit dependency `1.4.0` → `2.0.0`; the resolved 2.0.1 also makes **Cancel** the default
  button in the Uninstall pane, so Return lands on the safe choice.

## [2.1.0] - 2026-07-11

Rectangle-parity **drag-to-edge snapping**, configurable **window gaps**, and **startup
deferral**.

### Added
- **Window gaps** — a single configurable gap (points, default `0` = unchanged) applied as an
  outer screen-edge margin *and* between adjacent tiled windows, for halves, corners, thirds and
  fullscreen. `Center` and `Make Larger/Smaller` are unaffected. Includes a `Skip gap at the top
  edge` option. Exposed in the General settings pane and localized in all 7 languages.
- **Drag-to-edge snapping** — drag a window to a screen edge or corner to snap it, matching
  Rectangle's default behavior: top edge → maximize, corners → quarters, left/right edges →
  halves (top/bottom half within 145 pt of a corner), bottom edge → thirds with drag-toward-center
  two-thirds promotion. Includes a translucent footprint preview, undo support (drag-snaps record
  into the same history as keyboard actions), and unsnap-restore (grabbing a snapped window
  restores its pre-snap size under the cursor). Toggle in the General pane.
- Drag-snap honors the configured window gap; keyboard and drag-snap produce identical gapped
  frames for the same target.

### Changed
- **Startup deferral** — the 18 global hot-key registrations and the login-item (`SMAppService`)
  reconcile now run after the first runloop tick instead of blocking
  `applicationDidFinishLaunching`. No observable behavior change.
- `AppSettings` now uses a migration-safe custom decoder so existing users' stored preferences
  (`launchAtLogin`, `showInMenuBar`) survive the addition of the new gap/snap settings fields.

### Tests & coverage
`SpectacleCore` unit tests grew from **51 to 74** (+23), all passing. The parity-critical geometry
is fully unit-tested; the AppKit/AX/Carbon glue (drag monitors, footprint overlay, AX
under-cursor lookup, settings UI, startup ordering) is not headlessly testable and is verified by
`swift build` + the owner GUI e2e checklist in
`docs/superpowers/plans/2026-07-10-drag-snap-gaps-startup.md`.

- **`Tests/SpectacleCoreTests/GapTests.swift` (+9)** — window-gap math:
  - `gapInsetZeroIsIdentity`, `gapInsetShrinksAllEdgesByHalf`, `gapInsetSkipTopLeavesTopEdge` —
    the `WindowGap.inset` helper, including the Cocoa top-edge (`maxY`) skip case.
  - `gapZeroMatchesUngapped` — regression guard that `gap = 0` reproduces pre-existing results.
  - `gapLeftHalfHasOuterAndInnerGap` — full gap `G` at the outer edge *and* between two halves.
  - `gapFullscreenLeavesUniformMargin` — fullscreen gets a uniform full-`G` margin (consistent
    with a half-window's outer edge).
  - `gapDoesNotAffectCenter` — `Center` preserves size/position regardless of gap.
  - `gapCyclingStillAdvances` — the ½→⅔→⅓ repeat-press cycling still advances with a non-zero gap.
  - `gapSkipTopEdgeOnFullscreen` — `Skip gap at the top edge` removes only the top margin.
- **`Tests/SpectacleCoreTests/SnapGeometryTests.swift` (+14)** — drag-snap geometry:
  - Snap-target rects: `snapLeftHalfNoGap`, `snapMaximizeNoGap`, `snapTopLeftQuarterNoGap`,
    `snapThirdsPartitionTheWidth`, `snapTwoThirdsSpanTwoColumns`, `snapAppliesGap` (gap-aware,
    Cocoa bottom-left coordinates).
  - Cursor→zone classification (Rectangle constants — 5 pt edge, 20 pt corner, 145 pt short-edge):
    `zoneNilInInterior`, `zoneTopEdge`, `zoneBottomEdge`, `zoneLeftEdge`, `zoneCornerTopLeftWins`,
    `zoneCornerBottomRight` (corners win over edges), `sideHalfNearTopCorner`,
    `bottomEdgeThirdByCursorX`.
