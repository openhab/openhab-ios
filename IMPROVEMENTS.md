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
- [x] Cogwheel (gear) in collapsed header visible and animated — two-phase expand: ConnectionView + gear fade out (phase 1), layout collapses + chevron rotates (phase 2); exact mirror on collapse *(Layer 3A, committed)*
- [ ] Reload left / cogwheel right in collapsed header; home-name tap expands/collapses
- [x] Replace URL + credential text with connection-type symbols in rows: `.wifi`, `.cloudFill`, `.exclamationmarkIcloud` (outline; matches header error icon), no symbol when cloud service off *(Layer 3A/3B)*
- [x] Per-home avatar: circular 28×28 in menu rows, placeholder `houseFill` when no image set; blue ring replaces checkmark as active-home indicator; stored as file via `AvatarImageHelper` *(Layer 3B — menu side done; PhotosPicker + Home Settings = Layer 3C)*
- [x] Unified row height: normal mode and edit mode rows both `44 pt`; List constrained via `frame(height:)` + `.clipped()` + `.environment(\.defaultMinListRowHeight, rowHeight)` *(Layer 3B)*
- [x] Animated add/delete/mode-switch: `withAnimation` on all `homes` mutations; `.transition(.opacity)` on individual rows and on mode containers *(Layer 3B)*
- [x] Single Edit button; edit mode = add / delete / reorder only; cogwheels hidden in edit mode; full-width Add Home above Done; dimmed trash on active-home row keeps column alignment *(Layer 3B)*
- [ ] Full-row tap area fix (`contentShape` audit across all row types)
- [ ] Broken/missing connection shown as disconnected symbol in header
- [ ] Menu entries (sitemaps, pages, tiles) retained on connection loss; cleared only on home switch
- [ ] "Home" MainUI entry gated behind `hasEverSuccessfullyLoaded`

### Per-home section customisation (Home Settings — Layer 3C)

- [x] Home name editable via `TextField` in `HomeSettingsView`; included in `SettingsSnapshot` for dirty tracking; persisted on save *(Layer 3C)*
- [x] Avatar `PhotosPicker` in `HomeSettingsView`; saves via `AvatarImageHelper`; displayed as 72 pt circle next to the editable name; `@State` uses SwiftUI `Image` (not `UIImage`) *(Layer 3C)*
- [x] **"Disable remote connection" toggle** (`disableRemoteConnection` in `HomePreferences`): added to model + custom decoder; `trackedConnections` respects it; `NetworkConnectionService` now uses `trackedConnections` instead of building the list manually; `InlineHomePickerView.connectionSymbols` hides cloud symbol; `ConnectionSettingsView` shows a "Use Remote Connection" toggle that collapses the remote server section when off *(Layer 3C)*
- [x] **Avatar icon/circle color logic**: 3-zone HSL lightness (L < 0.30 / mid / L > 0.70) × 2 environments → 6-branch table; circle adapts only at extremes, icon always contrasts circle; `hexString` rounding fix (`lroundf`); `HomeAvatarColorTests` covers all 6 branches, invariants (complementarity, contrast), hue preservation *(Layer 3C)*
- [x] **Photo re-crop**: tapping the photo button when a photo is already set opens `CropImageView` directly on the stored `UIImage` instead of launching the gallery picker again *(Layer 3C)*
- [x] **Avatar in collapsed home menu header**: the per-home avatar should appear alongside the cogwheel and home name when the home section is collapsed, matching the same treatment given to the gear icon *(Layer 3C or 4)*
- [ ] **Deployment target iOS 18**: make the target consistently iOS 18 across the project (amend the first branch commit); audit and remove any `#available(iOS 17, *)` guards or iOS 17-era defensive code introduced during this branch under the wrong assumption
- [ ] Sections rearrangeable and individually hideable in Home Settings; expansion state shown read-only *(Layer 4 prerequisite)*

### System & App section (`systemMenu()` in `ToolbarMenu.swift`)

- [ ] Housekeeping actions (cache clear etc.) relocated from App Settings / Home Settings into this section
- [ ] Notifications row moved after App Settings; hidden when notifications disabled
