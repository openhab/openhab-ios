# Fundamentals

The core of App Intents is the `AppIntent` protocol. Every exposed app action conforms to it or to one of its subprotocols (`OpenIntent`, `AudioPlaybackIntent`, `VideoCallIntent`, `ForegroundContinuableIntent`, ...).

## Minimal intent

```swift
import AppIntents

struct RefreshFeedIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh feed"

    func perform() async throws -> some IntentResult {
        .result()
    }
}
```

Three required pieces:

- `static let title: LocalizedStringResource` - human-readable title; displayed in Shortcuts, Siri, focus filter pickers.
- `func perform() async throws -> some IntentResult` - the work. Always `async throws`; runs off the main actor unless you opt in.
- `.result()` - an empty `IntentResult` meaning "done, nothing to return".

`LocalizedStringResource` integrates with string catalogs and with SwiftUI's localization pipeline, so localized strings work everywhere App Intents displays them.

## Optional static metadata

A few more statics fine-tune how the intent presents:

```swift
struct RefreshFeedIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh feed"
    static let description = IntentDescription(
        "Pulls the latest articles from all your subscribed sources.",
        categoryName: "Reading",
        searchKeywords: ["refresh", "sync", "fetch"],
        resultValueName: "Articles"
    )
    static let isDiscoverable: Bool = true   // default
    static let openAppWhenRun: Bool = false  // default

    func perform() async throws -> some IntentResult { .result() }
}
```

- `description: IntentDescription` - the long-form blurb shown in Shortcuts under the action title. Accepts optional `categoryName:` (Shortcuts library category), `searchKeywords:` (extra search tokens Shortcuts matches against), and `resultValueName:` (the label used when the output of this intent is bound into another action, e.g., "Articles" in "Use Articles from Refresh Feed"). Include these whenever the intent returns a chainable value.
- `isDiscoverable` - when `false`, the intent is invisible in the Shortcuts library and Siri suggestions. Use for helper intents that only exist to back a widget button, a snippet button, or another intent. Keeps the user-facing library clean.
- `openAppWhenRun` - opens the app after `perform()` finishes. Prefer `OpenIntent` for user-visible navigation; reach for this only when the opening is a side-effect of a larger action.

## Common intent subprotocols

`AppIntent` is the baseline. Several subprotocols specialize the behavior; pick the most specific one that fits:

| Protocol | Purpose |
|---|---|
| `AppIntent` | Generic action. |
| `OpenIntent` | Opens the app to a specific entity (`target: MyEntity` parameter). See `open-and-snippet-intents.md`. |
| `SnippetIntent` | Renders a snippet view only - no business logic. Paired with `ShowsSnippetIntent` results. |
| `ForegroundContinuableIntent` | Can bring the app to the foreground mid-perform via `needsToContinueInForegroundError(...)`. For flows that require UI (login, permissions). |
| `DeleteIntent` | Deletes one or more entities; system may prompt for confirmation automatically. |
| `ShowInAppSearchResultsIntent` | Routes a search query into the app's own search UI. |
| `AudioPlaybackIntent` / `AudioStartingIntent` | Plays audio; integrates with lock-screen, CarPlay. |
| `VideoCallIntent` | Starts a video call. |
| `CameraCaptureIntent` | Starts a camera capture flow. |
| `ProgressReportingIntent` | Reports progress for long-running tasks; Shortcuts shows a progress bar automatically. Set `totalUnitCount`, bump `completedUnitCount` during `perform()`. (iOS 17+) |
| `LongRunningIntent` | Runs past the 30-second background budget via `performBackgroundTask`; surfaces a Live Activity; supports background GPU. Refines `ProgressReportingIntent`. (iOS 27+ - see `long-running-and-execution.md`) |
| `CancellableIntent` | Clean up gracefully with the cancellation *reason* via `withIntentCancellationHandler`. (iOS 26.4+ - see `long-running-and-execution.md`) |
| `URLRepresentableIntent` | Lets the system open the app via a universal link URL without your `perform()` running. Pairs with `URLRepresentableEntity`. See `open-and-snippet-intents.md`. |
| `TargetContentProvidingIntent` | Marker protocol on iOS - tells the system this intent produces the app scene users navigated to. Needed for visual intelligence routing back into the app. |
| `WidgetConfigurationIntent` | Marker protocol for an intent that's *only* used as widget configuration. Parameter queries drive the configuration picker; no user-invokable action. (iOS 17+ via WidgetKit's `AppIntentConfiguration`) |
| `ControlConfigurationIntent` | Same, but for Control Center controls (iOS 18+). An intent can be both the control's configuration and its tap action. |
| `PredictableIntent` | The system learns from prior invocations and suggests the intent proactively; tailor the description dynamically based on parameter values. (iOS 26+) |

## Foreground continuation

Intents sometimes need to bring the app forward mid-perform - to sign in, grant a permission, or finish something only the UI can handle. Three mechanisms, picked by iOS version.

### `ForegroundContinuableIntent` + `needsToContinueInForegroundError` (iOS 17+)

Throws an error, stops the intent, runs the closure when the user taps Continue:

```swift
struct SuggestArticlesIntent: ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Suggest articles"
    @Dependency var account: AccountManager
    @Dependency var navigation: NavigationModel

    @Parameter var topic: String?

    func perform() async throws -> some IntentResult & ReturnsValue<[ArticleEntity]> {
        if !account.loggedIn {
            let dialog = IntentDialog("You aren't logged in. Tap Continue to sign in.")
            throw needsToContinueInForegroundError(dialog) {
                navigation.route = .signIn
            }
        }

        let articles = try await account.suggestions(for: topic)
        return .result(value: articles)
    }
}
```

### `requestToContinueInForeground` (iOS 17+, non-throwing)

Same idea but returns a value so the intent can continue execution after foregrounding instead of restarting from scratch:

```swift
let result = try await requestToContinueInForeground(dialog) {
    await navigation.presentSignIn()  // returns user's chosen account
}
// result is whatever the closure returns; intent keeps running
```

Use when the foreground step yields data you need to finish the work.

### `supportedModes` + `continueInForeground` (iOS 26+)

The modern form. Declare which execution modes the intent supports, then decide dynamically inside `perform()`:

```swift
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start workout"
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Dependency var workoutManager: WorkoutManager

    func perform() async throws -> some IntentResult {
        if workoutManager.needsPermission {
            try await continueInForeground(alwaysConfirm: false)
        }
        try await workoutManager.start()
        return .result()
    }
}
```

Modes:

- `.background` - run without UI.
- `.foreground(.immediate)` - always foreground the app.
- `.foreground(.dynamic)` - may foreground based on `continueInForeground()` calls.
- `.foreground(.deferred)` - foreground after `perform()` completes.

`continueInForeground(alwaysConfirm:)` opens the app; `alwaysConfirm: false` skips the confirmation prompt if the device was recently active (trusts recency as implicit consent).

Prefer `supportedModes` + `continueInForeground` on iOS 26. `ForegroundContinuableIntent` / `needsToContinueInForegroundError` remain for backward compatibility.

## Background launch without scenes

When an intent runs with `openAppWhenRun = false`, the system launches your app process but does **not** bring up scenes - the UI hierarchy isn't constructed, no `body` properties run. Only `App.init()` executes.

Two consequences:

- Any intent-relevant setup must live in `App.init()` (see `dependencies.md`).
- If an intent later decides it needs UI (e.g., via `continueInForeground`), the system will create the scene at that point.

Background launches are significantly faster than scene launches. Keep `openAppWhenRun = false` whenever possible.

## Execution time and target

Two more lifecycle facts, both expanded in the 27 releases (full detail in `long-running-and-execution.md`):

- **30-second budget.** An intent triggered from any system surface gets ~30 seconds to finish (no hard limit on macOS). Past that it's killed. For uploads, sync, large file ops, or on-device inference, conform to `LongRunningIntent` and wrap the work in `performBackgroundTask`; for graceful cleanup on cancellation, conform to `CancellableIntent`.
- **Execution target.** When intents live in a shared package imported by the app *and* extensions, the system picks the process by heuristic. Override it with the `allowedExecutionTargets` type property (`IntentExecutionTargets`) - e.g. pin a data-mutating intent to the main app so a read-only widget extension never writes the shared store.

## Hard limits and character caps

App Intents have a few concrete caps worth knowing:

- **10 App Shortcuts per app.** The `AppShortcutsProvider.appShortcuts` array is capped at 10. Pick the most habitual actions.
- **1,000 total trigger phrases.** Includes all parameter expansions. A phrase like `"Open \(\.$folder) in \(.applicationName)"` with a 20-folder list counts as 20 phrases.
- **First phrase is the primary.** The first entry in `phrases:` becomes the tile label on the Shortcuts home, and the phrase Siri answers with when asked "What can I do with X?"

Plan phrase arrays with the primary-first rule in mind.

## Strings file location

App Intents metadata is extracted at build time by the Swift compiler. Localized strings for intent titles, descriptions, dialog, and parameter prompts must live in a `.strings` file or String Catalog **in the same module** as the intent types that reference them - a framework can't hold strings for intents defined elsewhere.

On iOS 17+ use the dedicated `AppShortcuts` String Catalog for shortcut phrases (see `shortcuts-and-siri.md`) - it removes the per-locale phrase-count limit that used to apply to Swift-declared phrases.

## Intents as the app's canonical action layer

Beyond Siri / Shortcuts / Spotlight exposure, intents also work well as your app's internal action vocabulary. When every user-facing action goes through an intent, the same types power:

- Siri and Shortcuts invocations.
- Widget `Button(intent:)` taps.
- Control Center controls.
- Live Activity buttons.
- Deep-link routing (via `OpenIntent` + `URLRepresentableIntent`).
- In-app SwiftUI `Button(intent:)` in views where it's convenient.

The single intent definition covers all of these without duplicated action-handling code. Even intents marked `isDiscoverable = false` (invisible to users in the Shortcuts library) still pay off because widgets, controls, and in-app buttons can invoke them.

This is a design choice, not a framework requirement - but when you adopt it, refactors become easier: you move an action into an intent once, and every surface that needs that action uses the same code path.

## "Everything should be an App Intent"

Apple's design guidance shifted at WWDC24: instead of exposing only the one or two most-habitual actions, treat every meaningful thing the app does as a potential intent. Caveats:

- Don't create one intent per variant of the same task (one flexible intent with a parameter is better than many near-duplicates).
- Don't expose UI-level actions as intents ("save draft", not "tap the save button").
- Parameter summaries must read as natural sentences for every combination of values.
- Start with habitual actions; expand coverage later.

The limit on the app-shortcuts array (10) still forces selectivity for the Siri / Action Button / Shortcuts-home surfaces. But the intent catalog itself can be much larger - the uncapped intents still surface in the Shortcuts editor and in downstream compositions.

## Return-type composition

`some IntentResult` is the base. Compose additional capabilities with `&`:

| Conformance | Meaning |
|---|---|
| `IntentResult` | Baseline - intent completed. |
| `ProvidesDialog` | Attaches spoken/shown dialog to the result. |
| `ReturnsValue<T>` | Returns a typed value chainable in Shortcuts. |
| `ShowsSnippetView` | Attaches a SwiftUI snippet view (widget-style). |
| `ShowsSnippetImage` | Attaches a single image. |
| `OpensIntent` | Opens the app when the intent completes. |

Examples:

```swift
// Dialog only
func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(dialog: "Feed refreshed.")
}

// Dialog + chainable value (Int, String, Bool, Double, Date, URL, AppEntity, or an array)
func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Int> {
    let count = try await service.unreadCount()
    let message = AttributedString(localized: "You have ^[\(count) unread article](inflect: true).")
    return .result(value: count, dialog: "\(message)")
}

// Dialog + SwiftUI snippet
func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    return .result(dialog: "\(entity.title)") {
        VStack {
            Image(systemName: "doc.text")
                .font(.largeTitle)
            Text(entity.summary)
        }
        .padding()
    }
}
```

The runtime checks the return shape: if you declare `ProvidesDialog` but return `.result()` without a dialog, it crashes at the call site - not at compile time. Match the signature to the call exactly.

## Perform concurrency

`perform()` is `async throws` and not main-actor by default. Anything you touch must either be `Sendable` or hop to the correct actor:

```swift
// Option A: pin the whole perform to the main actor (good when you need UI or SwiftData main context)
@MainActor
func perform() async throws -> some IntentResult {
    let items = try service.recent()
    return .result()
}

// Option B: stay off the main actor; hop only when needed
func perform() async throws -> some IntentResult {
    let summary = try await service.fetchSummary()
    await MainActor.run { uiCoordinator.present(summary) }
    return .result()
}
```

`@MainActor` on `perform()` is the pragmatic choice when the intent reads/writes SwiftData or mutates UI state - it's what Apple's own samples do.

## Intent dialog

`IntentDialog` is constructed by string interpolation of anything `LocalizedStringResource` or `AttributedString`:

```swift
return .result(dialog: "Saved \(count) items to \(folder.name).")
```

For pluralization use Foundation's automatic grammar agreement (markdown syntax, `^[...](inflect: true)`):

```swift
let count = 5
let message = AttributedString(localized: "Added ^[\(count) bookmark](inflect: true).")
return .result(dialog: "\(message)")
```

Output: "Added 1 bookmark." / "Added 5 bookmarks." Automatic agreement works in English, French, German, Italian, Spanish, and Portuguese (both variants). For other locales the text renders as-is, so write the singular form as the base.

You can provide richer dialog variants:

```swift
let dialog: IntentDialog = IntentDialog(
    full: "You have \(count) unread articles in your saved feed.",
    supporting: "\(count) unread"
)
return .result(dialog: dialog)
```

Siri chooses which variant to use based on context (voice vs. screen, short vs. long).

## Refreshing widgets and controls after state changes

When `perform()` mutates data that widgets, control widgets, or live activities display, reload their timelines before returning:

```swift
import AppIntents
import WidgetKit

struct AddBookmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "Add bookmark"

    @Parameter(title: "URL") var url: URL
    @Dependency var store: DataStore

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try store.addBookmark(url: url)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Saved.")
    }
}
```

`WidgetCenter.shared.reloadAllTimelines()` tells the system every registered widget is stale. For fine-grained reloads use `reloadTimelines(ofKind:)` with the widget kind string. Do this inside `perform()`, before returning - otherwise the widget keeps showing pre-change state until the next refresh tick.

## Errors

Throw from `perform()` to signal failure. Any `Error` works, but App Intents understands these well:

- `NeedsValueError(...)` - request a parameter the user hasn't supplied.
- `RequestDisambiguationError(...)` - ask the user to pick between several options.
- `ConfirmationRequiredError` - ask the user to confirm a destructive action.

```swift
throw $folder.needsValueError("Which folder should this go in?")
```

For general failures, throw a plain `Error` conforming to `CustomLocalizedStringResourceConvertible` so the dialog is localizable.

## Scope: what an intent should do

Apple's guidance (from WWDC24 onwards): "Anything your app does should be an App Intent." The practical interpretation:

- Expose small, discrete actions: refresh, create, append, mark-as-read, open-X, summarize-X.
- Do not authenticate *inside* an intent; assume the user is signed in, and return a `ProvidesDialog` result explaining if they aren't.
- Do not start lengthy UI flows from an intent; either return a snippet, open the app at the right place (`OpenIntent`), or return a value.
- Keep `perform()` reasonably fast; Siri will not wait indefinitely.
