# openHAB iOS Development Guide

## Build/Test Commands
- Build: `xcodebuild -workspace openHAB.xcworkspace -scheme openHAB`
- Test all: `fastlane unittests` or `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABTestsSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Single test: `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABTestsSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:openHABTestsSwift/TestClassName/testMethodName`
- If the exact simulator is unavailable, switch to an available iPhone simulator
- Beta build: `fastlane beta`
- UI tests: `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABUITests`

## Architecture
- **Main app**: openHAB/ - UIKit + SwiftUI hybrid iOS app targeting iOS 16+
- **Core library**: OpenHABCore/ - Swift Package with shared business logic, models, API clients
- **Watch app**: openHABWatch/ - watchOS companion app (watchOS 10+)
- **Extensions**: openHABIntents/ (Siri shortcuts), NotificationService/ (rich notifications)
- **Tests**: openHABTestsSwift/ (Swift Testing), openHABUITests/ (UI automation). For targeted bug fixes,  run only focused tests by default.
- **Dependencies**: Kingfisher (image loading), SwiftUI, Firebase, OpenAPI runtime, SFSafeSymbols

## Code Style
- Swift 6
- SwiftUI for new views
- Naming: PascalCase classes, camelCase properties/methods, OpenHAB prefix for core types
- Use SFSafeSymbols for SF Symbols
- Avoid force unwrapping, prefer optionals
- Error handling: Result types in OpenHABCore, UIKit error alerts in main app but transition to SwiftUI wherever possible
- Avoid trailing closure syntax when passing multiple closures (use parentheses for all closures to prevent multiple_closures_with_trailing_closure warnings)
- Respect "BuildTools/.swiftformat"  and "BuildTools/.swiftlint.yml"
- Always use Swift Regex with Swift 6 syntax
- Prefer `guard` for early exits over `if/else if` chains — when a branch returns, use `guard`/early return to flatten nesting
- Move logic to the type that owns the data — methods that operate on a type's internals belong on that type, not in the caller
- Drop argument labels for parameters already implied by the function name — use `_` for positional parameters whose meaning is obvious from the function name, keep labels only for semantically distinct parameters
- Prefer direct calls to shared helpers over thin wrapper closures that just forward arguments

## Rules for writing tests

- Always write tests with Swift Testing
- Add a parameter with a default value (e.g. `networkTracker: NetworkTracker = .shared`) to make functions testable without coupling them to singletons

## Verification cycle

After every set of code changes, always run a full verification cycle before committing:

1. **Build** using the Xcode MCP server (`mcp__xcode__BuildProject`, tab `windowtab1`). Fix any errors before proceeding.
2. **Install & run** in the simulator using the Xcode MCP server (build via Xcode, then `mcp__ios-simulator__install_app` + `mcp__ios-simulator__launch_app`).
3. **Visually confirm** the changed behaviour with `mcp__ios-simulator__screenshot` or `mcp__ios-simulator__record_video`. Walk through the affected screens interactively with `mcp__ios-simulator__ui_tap`, `mcp__ios-simulator__ui_describe_all`, etc.
4. Only commit once the simulator confirms the fix is working as expected.

## MCP servers and skills for Swift / iOS development

| Tool | When to use |
|------|-------------|
| `mcp__xcode__BuildProject` | Build the workspace (tab `windowtab1`). Prefer this over `xcodebuild` on the command line. |
| `mcp__xcode__XcodeListWindows` | Retrieve the current tab identifier before building. |
| `mcp__xcode__GetBuildLog` | Inspect detailed build output after a failure. |
| `mcp__xcode__RunAllTests` / `mcp__xcode__RunSomeTests` | Run the test suite without leaving Xcode. |
| `mcp__xcode__XcodeGrep` / `mcp__xcode__XcodeRead` | Search and read source files through Xcode's index. |
| `mcp__xcode__XcodeListNavigatorIssues` | List current compiler warnings/errors in the Xcode navigator. |
| `mcp__xcode__RenderPreview` | Render a SwiftUI `#Preview` without launching the full simulator. |
| `mcp__ios-simulator__get_booted_sim_id` | Get the UDID of the running simulator. |
| `mcp__ios-simulator__open_simulator` | Open Simulator.app if it is not already running. |
| `mcp__ios-simulator__install_app` | Sideload a freshly-built `.app` bundle onto the simulator. |
| `mcp__ios-simulator__launch_app` | Launch the installed app by bundle ID. |
| `mcp__ios-simulator__screenshot` | Capture the current simulator screen for visual verification. |
| `mcp__ios-simulator__record_video` | Record a walkthrough video. Close all other simulators first so the tool targets the right device. |
| `mcp__ios-simulator__ui_tap` / `mcp__ios-simulator__ui_type` / `mcp__ios-simulator__ui_swipe` | Interact with the running app. |
| `mcp__ios-simulator__ui_describe_all` / `mcp__ios-simulator__ui_describe_point` / `mcp__ios-simulator__ui_view` | Inspect the accessibility tree to find element coordinates. Prefer this over screenshots for determining tap targets and verifying text content. Only take a screenshot when confirming graphical/visual changes (layout, new UI components, color/style). |

## git
- Always use git commit with -s -S
