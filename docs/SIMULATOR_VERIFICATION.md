# Simulator & Xcode MCP — Verification Guide

Reference this document when running the verification cycle after code changes.

## MCP server roles

Two MCP servers are in use. Their responsibilities are strictly separated:

| Server | Use for |
|--------|---------|
| `ios-simulator` | Simulator lifecycle only: list, boot, shutdown |
| `mobile-mcp` | Everything else: install, launch, interact, screenshot, recording, crashes |

`ios-simulator` tools for install, launch, terminate, and tap all require a `sessionId` that cannot be obtained on iOS 26.5 — those tools are inaccessible and must not be used.

## Verification cycle

After every set of code changes, always run a full verification cycle before committing:

1. **Build** using the Xcode MCP server (`mcp__xcode__BuildProject`, tab `windowtab1`). Fix any errors before proceeding.
2. **Install & run** in the simulator:
   - After a successful build, read the build log (`mcp__xcode__GetBuildLog`) and extract the `.app` bundle path. **Always use the path from the current build log** — never reuse a hardcoded or previously seen path, as it will point to a stale bundle.
   - Call `mcp__mobile-mcp__mobile_terminate_app` (bundle ID `org.openhab.app`) to kill any running instance.
   - Call `mcp__mobile-mcp__mobile_install_app` with the fresh `.app` path to replace the on-disk bundle.
   - Call `mcp__mobile-mcp__mobile_launch_app` to start the newly installed version.
   - **Never skip the terminate → install → launch sequence.** Calling only `launch_app` without a fresh install will start the previously installed binary.
3. **Visually confirm** the changed behaviour. Walk through the affected screens interactively:
   - **Before tapping**, take a screenshot (`mcp__mobile-mcp__mobile_take_screenshot`) to confirm the app is visible and running. If the screen is blank or shows the home screen, the app has not launched or has crashed — call `mcp__mobile-mcp__mobile_launch_app` again before retrying.
   - **Always call `mobile_list_elements_on_screen` before tapping** to get element coordinates from the `coordinates` field `{x, y, width, height}`. Compute the tap target as `x + width/2, y + height/2`. Never derive coordinates from screenshot pixel positions.
   - Use `mcp__mobile-mcp__mobile_take_screenshot` only when verifying graphical/visual changes (layout, new UI components, colour/style) — not for deriving tap coordinates.
4. Only commit once the simulator confirms the fix is working as expected.

## MCP tool reference

### Xcode

| Tool | When to use |
|------|-------------|
| `mcp__xcode__BuildProject` | Build the workspace (tab `windowtab1`). Prefer this over `xcodebuild` on the command line. |
| `mcp__xcode__XcodeListWindows` | Retrieve the current tab identifier before building. |
| `mcp__xcode__GetBuildLog` | Inspect detailed build output after a failure. |
| `mcp__xcode__RunAllTests` / `mcp__xcode__RunSomeTests` | Run the test suite without leaving Xcode. |
| `mcp__xcode__XcodeGrep` / `mcp__xcode__XcodeRead` | Search and read source files through Xcode's index. |
| `mcp__xcode__XcodeListNavigatorIssues` | List current compiler warnings/errors in the Xcode navigator. |
| `mcp__xcode__RenderPreview` | Render a SwiftUI `#Preview` without launching the full simulator. |

### ios-simulator (lifecycle only)

| Tool | When to use |
|------|-------------|
| `mcp__ios-simulator__list-booted-simulators` | Get the UDID of the running simulator. |
| `mcp__ios-simulator__list-available-simulators` | See all simulators and their UDIDs (use raw JSON — table display has a bug). |
| `mcp__ios-simulator__boot-simulator-by-udid` | Boot a specific simulator by UDID. |
| `mcp__ios-simulator__shutdown-simulator-by-udid` | Shut down a simulator by UDID. |

### mobile-mcp (all UI interaction)

| Tool | When to use |
|------|-------------|
| `mcp__mobile-mcp__mobile_list_available_devices` | Confirm the device UDID when uncertain. |
| `mcp__mobile-mcp__mobile_install_app` | Sideload a freshly-built `.app` bundle onto the simulator. |
| `mcp__mobile-mcp__mobile_launch_app` | Launch the installed app by bundle ID. |
| `mcp__mobile-mcp__mobile_terminate_app` | Kill the running app. |
| `mcp__mobile-mcp__mobile_list_apps` | List all installed apps with bundle IDs. |
| `mcp__mobile-mcp__mobile_take_screenshot` | Capture the current screen for visual verification. |
| `mcp__mobile-mcp__mobile_list_elements_on_screen` | Inspect the AX tree to find element coordinates. **Use before every tap.** |
| `mcp__mobile-mcp__mobile_click_on_screen_at_coordinates` | Tap at pixel coordinates. |
| `mcp__mobile-mcp__mobile_double_tap_on_screen` | Double-tap at pixel coordinates. |
| `mcp__mobile-mcp__mobile_long_press_on_screen_at_coordinates` | Long-press (default 500 ms, configurable). |
| `mcp__mobile-mcp__mobile_swipe_on_screen` | Swipe in a direction from an optional start point. |
| `mcp__mobile-mcp__mobile_type_keys` | Type text into the focused element; optionally submit. |
| `mcp__mobile-mcp__mobile_press_button` | Press hardware buttons: HOME, VOLUME_UP, VOLUME_DOWN, ENTER. |
| `mcp__mobile-mcp__mobile_get_screen_size` | Get screen pixel dimensions (returns e.g. `402x874 pixels`). |
| `mcp__mobile-mcp__mobile_get_orientation` / `mobile_set_orientation` | Query or change portrait/landscape. |
| `mcp__mobile-mcp__mobile_start_screen_recording` / `mobile_stop_screen_recording` | Record a walkthrough as MP4. |
| `mcp__mobile-mcp__mobile_list_crashes` / `mobile_get_crash` | Access crash reports for diagnosis. |
| `mcp__mobile-mcp__mobile_open_url` | Open a URL in the device browser. |

**Coordinate note:** `mobile-mcp` coordinates are in pixels matching the screenshot dimensions — no logical-point conversion needed. iPhone 17 on iOS 26.5 is 402×874 px.
