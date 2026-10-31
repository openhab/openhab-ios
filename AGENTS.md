# openHAB iOS Development Guide

## Editing files
Prefer the Xcode MCP tools (`XcodeRead`, `XcodeUpdate`, `XcodeWrite`, `XcodeMV`, `XcodeRM`, `XcodeGrep`, `XcodeGlob`) over `Edit`, `Write`, `mv`, `rm`, shell scripts or `sed` when the Xcode MCP is available. They work on the project structure, so renames, moves and deletions keep the project file in sync, and Xcode sees every change at once. Fall back to the other tools only for files outside the project (e.g. `AGENTS.md`, `.agents/`, CI config) or when the Xcode MCP is not available.

## Build/Test Commands
Prefer the Xcode MCP tools (`BuildProject`, `RunSomeTests`, `RunAllTests`, `RunProject`, `GetBuildLog`) over `xcodebuild`. Fall back to the command line below only when the Xcode MCP is not available.
- Pick the scheme with `XcodeSwitchScheme`: `openHABTestsSwift` for unit tests, `openHABUITests` for UI tests, `openHAB` to run the app. Check `activeDestinationDisplayTitle` in its answer: it can pick a physical device. Switch to a simulator with `XcodeSwitchRunDestination` before running anything
- Build (compile check): `BuildProject`
- Test all: `RunAllTests`. Single test or suite: `RunSomeTests` with the target name and test identifier, e.g. `MainUILoginTests` or `ToolbarMenuUITests/testTapOutsideClosesTheMenu()`
- Run the app: `RunProject` (with `attachDebugger: true` to use `InvokeDebuggerCommand`)
- Never search for, create, or download simulators or runtimes. Use one of the destinations `XcodeListRunDestinations` lists. If none is usable, stop and report
- `DeviceInteractionInstallAndRun` and `XcodeSwitchScheme` can rewrite the launcher keys of `openHAB.xcscheme`. Run `git checkout -- openHAB.xcodeproj/xcshareddata/xcschemes/openHAB.xcscheme` before committing

### Command line (only if the Xcode MCP is not available)
- Build (compile check): `xcodebuild -workspace openHAB.xcworkspace -scheme openHAB -destination 'generic/platform=iOS Simulator' build` — no specific simulator needed
- Simulator for tests: pick an installed iPhone with one command, never by hand or by guessing model names:
  `SIM=$(xcrun simctl list devices available -j | jq -r '[.devices | to_entries[] | select(.key | contains("iOS")) | .value[] | select(.name | startswith("iPhone"))] | (map(select(.state == "Booted")) + .)[0].udid')`
- Test all: `fastlane unittests` or `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABTestsSwift -destination "platform=iOS Simulator,id=$SIM"`
- Single test: `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABTestsSwift -destination "platform=iOS Simulator,id=$SIM" -only-testing:openHABTestsSwift/TestClassName/testMethodName`
- Never search for, create, or download simulators or runtimes. If `$SIM` is empty or the destination fails, stop and report instead of retrying other devices
- UI tests: `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABUITests -destination "platform=iOS Simulator,id=$SIM"`

### Release
- Beta build: `fastlane beta`

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
- **Always write UI tests** for any new or modified UI surface. See **[.agents/docs/UI_TESTING_GUIDE.md](.agents/docs/UI_TESTING_GUIDE.md)** for the full guide, including how to register new test files, inject test state, write layout assertions, and pitfalls to avoid.

## Verification cycle

After every set of code changes, run a full verification cycle before committing. This applies only to tasks where you edited code: reviews, explanations, and investigations are read-only — never build, test, or boot simulators for them. See **[.agents/docs/SIMULATOR_VERIFICATION.md](.agents/docs/SIMULATOR_VERIFICATION.md)** for the step-by-step process and full MCP tool reference.

To replicate the MCP server setup, see **[.agents/docs/MCP_SETUP.md](.agents/docs/MCP_SETUP.md)**.

## git
- Always use git commit with -s (signed-off-by)
- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.

## Agent configuration layout
- `AGENTS.md` is the single source of instructions for all agents (Copilot, Codex, Cursor, Claude, ...). `CLAUDE.md` only imports it via `@AGENTS.md`; do not duplicate content there.
- Shared skills live in `.agents/skills/` (installed with `npx skills`, pinned in `skills-lock.json`). `.claude/skills/` contains relative symlinks to them for Claude Code.
- Longer guides referenced from this file live in `.agents/docs/`.
- Personal setup stays untracked: `.claude/settings.local.json`, `CLAUDE.local.md`, `.claude/worktrees/`, and skills named `local-*` (in `.agents/skills/` and `.claude/skills/`). User-wide skills belong in `~/.claude/skills` or `~/.agents/skills`.
