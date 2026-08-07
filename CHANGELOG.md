# Changelog

All notable changes to Spectacle 2 are documented here. This project adheres to
[Semantic Versioning](https://semver.org/).

## [2.4.1] - 2026-08-07

### Fixed
- **The About panel showed the version in the wrong format.** It read `2.4.0 (754)`, missing both
  the `v` prefix and the ` · <UTC build time>` suffix that every other Dragon app shows. It now
  reads `v2.4.1 (<build>) · <UTC build time>`.

  `AboutConfig` built the string by hand instead of calling `DragonAbout.versionString()`, which
  `docs/ADOPT-DRAGONKIT-PROMPT.md` and `docs/STARTING-A-NEW-APP.md` in the kit both require. The
  reason is a nineteen-minute race: `DragonAbout` was merged to the kit at 22:21 on 2026-07-06 and
  first shipped in kit v1.3.0, while this app was scaffolded at 22:40 the same evening pinned to
  `from: "1.2.1"` — so at that moment there was no helper to call and hand-rolling was correct.
  The stopgap then survived five kit bumps (1.2.1 -> 2.0.0 -> 2.1.0 -> 2.3.0 -> 2.4.0) untouched,
  because nothing enforces it: `dragon-conformance.py` rules R1-R11 contain no check for the About
  version format, so every release passed conformance with the wrong string. clipmenu-2, ice-2 and
  yahoo-keykey-2 all call the helper; this app was the only one that did not.

## [2.4.0] - 2026-08-07

Takes **DragonKit 2.4.0**. This is a currency bump, not a fix: conformance rule R10 requires the
declared pin to be at least the newest kit tag, and 2.4.0 was tagged the same day 2.3.0 shipped
here. Nothing in it repairs a defect this app had.

### Added
- **Hide, Hide Others and Show All in the Settings window's menu bar.** 2.3.0 gave that window a
  menu bar whose application menu held only Quit; the kit now fills in the three conventional
  commands above it. The Edit and Window menus are unchanged, and the menu-bar dropdown — which
  this app builds from `DragonAppMenu` — is untouched by the kit release.

### Changed
- DragonKit 2.3.0 -> 2.4.0 in `Package.swift`, still pinned with `exact:`.

The kit's headline change in 2.4.0 is a new `includeQuit:` parameter, which lets a system-managed
input method keep Quit ⌘Q out of its Settings menu bar. It does not apply here: Spectacle 2 is quit
by the user, so it takes the default and keeps Quit in both the Settings menu bar and the dropdown.
Recorded so this entry can't be read as adopting a behaviour the app doesn't use.

## [2.3.0] - 2026-08-07

Takes **DragonKit 2.3.0**, held back in 2.2.2 until it could be adopted deliberately. Every change
below comes from the kit rather than this app's own code, and all of it is user-visible — which is
why this is a minor bump rather than a patch.

### Added
- **The Settings window has a menu bar again.** An accessory app that promotes itself to `.regular`
  with no main menu shows an empty menu bar, which meant the Settings window had no ⌘W, no ⌘Q, and
  no Cut/Copy/Paste/Select All in any text field — including the search field in the Shortcuts
  pane. The kit now installs a minimal menu bar while the window is open. This was raised as a
  finding against 2.2.0 and deliberately fixed upstream rather than patched here, so that every
  Dragon app gets it.

### Fixed
- **Restoring a file that isn't a Spectacle 2 backup could erase your settings.** Backup
  deserialization accepted any property list, so an unrelated file passed validation and the
  restore then replaced the settings suite with nothing — while the pane relaunched the app as
  though it had succeeded. Both required keys are now checked, and a backup taken from a different
  app's suite is refused.
- **A failed uninstall reported success.** Moving the app to the Trash could fail *after* the
  settings teardown had already run; the error was discarded and the app quit claiming it was
  done, leaving it installed with its settings gone.
- **"Back Up Now" no longer writes duplicate snapshots.** If nothing changed since the newest
  backup, the pane says so instead of silently adding an identical file — ten redundant snapshots
  could previously push the last genuinely different one out of the retention window.
- Backup file I/O moved off the main actor, so a backup folder on a slow network share no longer
  freezes the Settings window, and the Permissions pane stopped rebuilding its entire view and
  polling TCC once a second forever.

### Removed
- **The "back up automatically on quit" toggle.** Nothing in the kit or in any app ever read the
  preference it wrote. It shipped on by default and did nothing, while telling users their
  settings were being backed up at quit. Existing installs keep a harmless orphaned key.

### Changed
- Permission status no longer refreshes while the app is in the background; it refreshes the
  moment the app becomes active.
- The kit's own permission titles and descriptions were hardcoded English that no app could
  translate. They are localized in all seven languages now, and the per-row delete button in
  Backup & Restore has a VoiceOver label naming the file instead of being one unlabelled trash
  icon among identical ones.

### Note on the settings-reset bug
DragonKit 2.2.0's headline fix — synthesized `Decodable` not falling back to a property's default
for a missing key, resetting every preference on upgrade — **did not affect Spectacle 2**. This
app's `AppSettings` has always used a hand-written tolerant decoder that supplies a default for
each absent field, and 2.2.1 added tests covering it. The kit's forward-migration is taken here
regardless, and it now preserves a stored blob it genuinely cannot read rather than dropping it.

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
