# openHAB iOS Development Guide

## Build/Test Commands
- Build (compile check): `xcodebuild -workspace openHAB.xcworkspace -scheme openHAB -destination 'generic/platform=iOS Simulator' build` — no specific simulator needed
- Simulator for tests: pick an installed iPhone with one command, never by hand or by guessing model names:
  `SIM=$(xcrun simctl list devices available -j | jq -r '[.devices | to_entries[] | select(.key | contains("iOS")) | .value[] | select(.name | startswith("iPhone"))] | (map(select(.state == "Booted")) + .)[0].udid')`
- Test all: `fastlane unittests` or `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABTestsSwift -destination "platform=iOS Simulator,id=$SIM"`
- Single test: `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABTestsSwift -destination "platform=iOS Simulator,id=$SIM" -only-testing:openHABTestsSwift/TestClassName/testMethodName`
- Never search for, create, or download simulators or runtimes. If `$SIM` is empty or the destination fails, stop and report instead of retrying other devices
- Beta build: `fastlane beta`
- UI tests: `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABUITests -destination "platform=iOS Simulator,id=$SIM"`

## Architecture
- **Main app**: openHAB/ - SwiftUI iOS app targeting iOS 18+ (UIKit still present in some files, goal is full removal)
- **Core library**: OpenHABCore/ - Swift Package with shared business logic, models, API clients
- **Watch app**: openHABWatch/ - watchOS companion app (watchOS 11+)
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
- **Always write UI tests** for any new or modified UI surface. See **[docs/UI_TESTING_GUIDE.md](docs/UI_TESTING_GUIDE.md)** for the full guide, including how to register new test files, inject test state, write layout assertions, and pitfalls to avoid.

## Verification cycle

After every set of code changes, run a full verification cycle before committing. This applies only to tasks where you edited code: reviews, explanations, and investigations are read-only — never build, test, or boot simulators for them. See **[docs/SIMULATOR_VERIFICATION.md](docs/SIMULATOR_VERIFICATION.md)** for the step-by-step process and full MCP tool reference.

To replicate the MCP server setup, see **[docs/MCP_SETUP.md](docs/MCP_SETUP.md)**.

## git
- Always use git commit with -s (signed-off-by)
- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.
