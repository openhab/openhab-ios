# MenuDataService: tests to restore and add

`MenuDataService` was changed in "fix(menu): load menu data in cancellable per-part tasks". Four tests in
`openHABTestsSwift/MenuDataTests.swift` used APIs that no longer exist (`hasSuccessfullyLoaded`,
`whileLoading`, `fetchesInFlight`, `refresh(running:)`) and were deleted instead of rewritten, because
the new design needs a way to inject what a load fetches, and that has not been decided yet (a
closure-based seam was tried and rejected as too intrusive). This file records what the deleted tests
covered, so the coverage can be restored.

## Deleted tests

### `hasSuccessfullyLoaded is false on init`, `clearAll does not reset hasSuccessfullyLoaded`
Covered the load gate for the "Home" menu row. The flag was removed (it had no documented purpose),
so there is nothing to restore. The `clearForHomeSwitch` test lost its flag assertions and keeps
checking that the three collections are emptied.

### `isLoading stays on until the last of overlapping fetches ends`
Two fetches overlapped; `isLoading` had to stay true until the second one finished, not turn false
when the first did. With one task per part, the same property is: `isLoading` is true while any part
is loading, and false only when the last part has finished or been cancelled.

To restore: start loads whose parts finish at different times, and check `isLoading` after each one.

### `a cancelled pull-to-refresh does not cancel the reload it started`
SwiftUI cancels the task of `.refreshable` when the menu re-renders; the reload must keep running and
finish anyway. `refresh(running:)` was removed because loads are tasks of their own now.

To restore: call `reload()` / `refresh()` from a task, cancel that task while the parts are still
loading, and check that the parts' tasks were not cancelled and that their data still arrives.

## New behaviour that has no test yet

- **A cancelled load never writes.** Start a load, call `clearForHomeSwitch()` (or start a newer
  load), let the old fetch finish, and check that `uiPages`, `sitemaps`, `uiTiles` and `server` are
  still empty or hold the newer data. This is the original bug: the pages of the previous home
  showed up after a home switch.
- **Parts apply independently.** A slow part must not delay the others; each property is set as soon
  as its own fetch returns.
- **A failing part keeps what the menu has.** If one fetch throws, only that property stays as it
  was, and the others are updated.
- **A newer load replaces an older one per part.**
- **`clearAll()` and `clearForHomeSwitch()` cancel loads in progress**, so `isLoading` is false
  afterwards.
- **The connection stream loads only when the connection target changes.** The tracker's state also
  changes with its status, the retry deadline and the network's reachability, so one new connection
  arrives as several states with the same `activeConnection`. Only another connection, or none in
  between, may start a load. `reload()`, pull-to-refresh and the reload button always load.

## What the tests need

A way to control each part's fetch from a test, for example one that holds a fetch open until the
test lets it finish (an `AsyncStream` as the old tests used), and one that makes it throw. The
production code builds an `OpenAPIService` inside `load(from:)` and calls four of its methods, so any
approach needs a seam there. Decide on its shape first; do not add it just for the tests if a
smaller one exists.

## Follow-ups outside this branch

- **Review the `root-view-tabbed-swiftui` branches** (`root-view-tabbed-swiftui` and
  `root-view-tabbed-swiftui-original`, work from Feb 14 to Mar 15 2026) and decide what is still
  applicable. The branches were not merged. What I could see from the history:
  - A `TabView` navigation that replaces the SideMenu drawer, with per-home tab customization and
    reordering (`f6a9f568`, `70e8ad62`, `4d3bc1c3`, `22ab7905`, `dbb7a3cd`), and UI tests for it
    (`35d84936`).
  - An async `Preferences` API (no `@MainActor`) that exposes `AsyncChannel` streams instead of
    Combine subjects (`a316bad9`, `09a7fdd1`), with `AsyncAlgorithms` imported in `Preferences`,
    `AppDelegate`, `WatchMessageService` and `AppServicesViewModel`.
  - The SwiftUI app lifecycle without `Main.storyboard` (`95ab7b75`) and a project reorganization
    (`0b71d8b1`). `develop` has since adopted its own versions of parts of this.
  - The commit counts `git` reports against `develop` (703 and 565) are inflated by rebases; use the
    commits above, not the counts.
- **Add `swift-async-algorithms` to the project.** The branches used it, `develop` does not have it,
  and it is wanted for replacing the remaining Combine usage. Not needed for `MenuDataService`.
  Files that still `import Combine` on `develop`: `OpenHABWidget`, `Preferences`,
  `SitemapPageViewModel` (three files), `NetworkConnectionService`, `NotificationsView`,
  `OpenHABRootView`, `OpenHABWebViewContainer`, `OpenHABWebViewModel`, `ScreenSaverView`, `IconView`.
  PR #1373 (timbms, `@Observable` for `OpenHABWidget` and `IconReloadCoordinator`) removes two of
  them and does not use `AsyncAlgorithms`.

## UI tests added on this branch

`ToolbarMenuUITests` has `testMenuOpensWhileTheHomeIsLoading` and `testMenuReopensAfterPickingAHome`.
Neither fails on the code as it was, so they are smoke tests, not regression tests for a bug. The
menu is unresponsive for about 1.2–1.4 s while its popover is dismissed after a home switch (and
after a plain close). That is the system's popover transition, not the loading state; no test covers
it.
