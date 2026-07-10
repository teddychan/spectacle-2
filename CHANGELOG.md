# Changelog

All notable changes to Spectacle 2 are documented here. This project adheres to
[Semantic Versioning](https://semver.org/).

## [Unreleased]

Rectangle-parity **drag-to-edge snapping**, configurable **window gaps**, and **startup
deferral**. No release/tag is cut by this entry.

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
