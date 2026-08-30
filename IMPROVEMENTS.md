# Menu Improvements — Hand-off Document

Branch: `menustructure_improvements` (based on `develop`)

This document is the single source of truth for a planned overhaul of the main toolbar-dropdown menu and its home section. It is written to be self-contained so a new conversation can continue without losing context.

---

## Background

PR #1165 introduced the current toolbar dropdown menu to replace the old side-drawer. Discussion #1316 on GitHub (`openhab/openhab-ios`) collected community feedback and shaped the decisions recorded here.

---

## Key files

| File | Role |
|---|---|
| `openHAB/UI/ToolbarMenu.swift` | Toolbar dropdown: sections, rows, expansion state, home header |
| `openHAB/UI/InlineHomePickerView.swift` | Home picker embedded inside the menu when expanded |
| `openHAB/UI/MenuDataService.swift` | Loads and publishes sitemaps, UI pages, tiles for the menu |
| `openHAB/UI/OpenHABRootView.swift` | Root view; hosts `ToolbarMenu`, handles selection, shows notifications sheet |
| `openHAB/UI/SettingsView/HomeSettingsView.swift` | Per-home settings sheet |
| `openHAB/UI/SettingsView/AppSettingsView.swift` | App-wide settings sheet |
| `OpenHABCore/Sources/OpenHABCore/Util/Preferences.swift` | `Preferences` singleton; `HomePreferences` struct persisted per home |

Notification visibility is currently gated by `Preferences.shared.getNotificationConnection() != nil` in `ToolbarMenu.systemMenu()`.

---

## Implementation plan

The work is divided into five layers ordered by dependency. Layers 1 and 2 are independent of each other and can be done in parallel.

### Layer 1 — `HomePreferences` data model *(prerequisite for Layers 3 & 4)*

- Add `avatarImagePath: String?` to `HomePreferences`.
- Add section order array + per-section visibility flags to `HomePreferences`.
- Write an image save/load helper:
  - Save file to `~/Library/Application Support/homes/<uuid>.jpg`.
  - Before writing, downscale so the image is at most the device's full native screen resolution in pixels (future-proofing: may become a background image later).
  - Store only the file path in `HomePreferences`, never raw `Data` in UserDefaults.

### Layer 2 — `MenuDataService` state management *(prerequisite for Layer 3)*

- Retain the last-good sitemaps/pages/tiles snapshot across connection drops. Clear it only on home switch, not on connection loss.
- On home switch: clear immediately and enter loading state until the new home responds.
- Track a `hasEverSuccessfullyLoaded` flag per home to gate the "Home" MainUI row (see item below).
- Expose the current connection state (connected/disconnected) so the home header can show the correct symbol.

### Layer 3 — `InlineHomePickerView` + home header *(needs Layers 1 & 2)*

All items below touch the same views; implement together to avoid multiple passes.

- Fix full-row tap areas (`.contentShape(Rectangle())` missing or misplaced).
- Suppress `ConnectionView` subtitle in the collapsed header when the homes list is expanded (subtitle = current home name, redundant when all homes are listed below).
- Merge the home-name tap area into the section-expansion tap target (tapping the name expands/collapses the list; it does NOT reload).
- Collapsed header layout: **reload button on the left, cogwheel on the right** (both always visible in normal mode).
- Cogwheels are hidden in edit mode — edit mode is exclusively for add, delete, and reorder.
- Home rows: replace raw URL + credential text with symbols:
  - `.wifi` — local connection active/configured.
  - `.cloudFill` — remote/myopenHAB connection active/configured with credentials.
  - `.cloudSlash` — remote connection configured but no credentials (invalid).
  - No cloud symbol at all — openHAB Cloud Service toggle is explicitly switched off.
  - Disconnected state (no active connection): show `.wifiExclamationmark` or `.cloudSlash` in the header instead of the normal type symbol.
- Per-home circular avatar: shown at the start of each home row when a picture is set. Uses `PhotosPicker` (no custom icon grid). In Home Settings, show it larger next to the editable home name.
- Edit mode streamlining:
  - Single **Edit** button replaces the current "edit" + "add home" pair.
  - In edit mode: drag handles for reordering (order saved immediately), delete icon on non-current-home rows (deletion triggers a confirmation dialog — keep current behaviour), full-width **Add Home** button above the **Done** button.
  - Home names are NOT editable from the menu; name editing is in Home Settings only.
  - Adding a home: show a cancellable name-entry alert. On confirm, create the home and immediately navigate to its settings.
- "Home" (root MainUI entry) hidden until `MenuDataService.hasEverSuccessfullyLoaded` is true for that home; behaves like sitemaps/pages in the loading state.

### Layer 4 — `ToolbarMenu` structural changes *(needs Layer 1)*

- Render sections dynamically from the persisted order/visibility in `HomePreferences` instead of hardcoded.
- Home Settings gets a section management UI: drag handles for reorder, toggles for visibility, read-only expansion-state indicator (chevron/label). The expansion state is not editable here — it is set implicitly by collapsing/expanding in the menu.

### Layer 5 — System & App section *(independent)*

- Move Notifications row to appear **after** App Settings (currently before).
- Hide Notifications row entirely when notifications are disabled. Gate condition: `Preferences.shared.getNotificationConnection() != nil` AND notifications not disabled in settings (verify which preference key controls this).
- Audit `AppSettingsView` and `HomeSettingsView` for cache-clearing and other housekeeping actions; move them into the System & App section of the menu.

---

## Testing policy

Write tests only for complex logic or behaviour that spans multiple layers. Skip trivial getter/setter unit tests.

Specific candidates:

- **Avatar image helper** (Layer 1): downscale-to-screen-resolution logic; file write/read round-trip; path stored in `HomePreferences` after save.
- **`MenuDataService` state machine** (Layer 2): snapshot retained on connection drop, cleared on home switch; `hasEverSuccessfullyLoaded` gate correct on first load vs. reconnect.
- **Connection symbol mapping** (Layer 3): parameterised test over `(localURL, remoteURL, hasCredentials, cloudServiceEnabled, isConnected)` → expected symbol set. Cases to cover: local active, cloud active with credentials, cloud active no credentials, cloud service off, offline.
- **Section order/visibility persistence** (Layer 4): round-trip through `HomePreferences`; `ToolbarMenu` renders sections in persisted order.
- **Notification visibility gate** (Layer 5): combined condition maps correctly to shown/hidden.

---

## Improvements checklist

### Home section header (`homeHeader()` / `homesMenu()` in `ToolbarMenu.swift`)

- [ ] Subtitle duplication when expanded — suppress `ConnectionView` home-name subtitle while `isHomeExpanded == true`
- [ ] Reload left / cogwheel right in collapsed header; home-name tap expands/collapses
- [ ] Replace URL + credential text with connection-type symbols (wifi / cloud / struck-through cloud / no-cloud / disconnected)
- [ ] Per-home avatar: `PhotosPicker`, circular in menu, larger in Home Settings; stored as file, downscaled to screen resolution
- [ ] Full-row tap area fix (`contentShape` audit across all row types)
- [ ] Broken/missing connection shown as disconnected symbol in header
- [ ] Menu entries (sitemaps, pages, tiles) retained on connection loss; cleared only on home switch
- [ ] "Home" MainUI entry gated behind `hasEverSuccessfullyLoaded`
- [ ] Single Edit button; edit mode = add / delete / reorder only; cogwheels hidden in edit mode; full-width Add Home above Done

### Per-home section customisation (Home Settings)

- [ ] Home name editable via `TextField` in `HomeSettingsView`
- [ ] Avatar `PhotosPicker` in `HomeSettingsView`; save/persist via `AvatarImageHelper`; shown larger next to editable name
- [ ] **"Disable remote connection" toggle** per home in `HomeSettingsView`: when off, the remote/cloud connection is excluded everywhere credentials are retrieved or passed (connection pool, `NetworkTracker`, `OpenHABAccessTokenAdapter`, etc.), and no cloud icon is shown for that home in `InlineHomePickerView`. Persisted as a `Bool` flag in `HomePreferences`. The existing "openHAB Cloud Service" toggle already controls *push notifications* independently — this new toggle controls whether the remote URL is used for *data connections* at all.
- [ ] Sections rearrangeable and individually hideable in Home Settings; expansion state shown read-only *(Layer 4 prerequisite)*

### System & App section (`systemMenu()` in `ToolbarMenu.swift`)

- [ ] Housekeeping actions (cache clear etc.) relocated from App Settings / Home Settings into this section
- [ ] Notifications row moved after App Settings; hidden when notifications disabled
