# Shortcuts and Siri

Writing an `AppIntent` type is not enough. The system discovers intents through an `AppShortcutsProvider`. Anything not listed there is invisible to Shortcuts, Siri suggestions, the action button picker, and most automation surfaces.

## `AppShortcutsProvider`

```swift
import AppIntents

struct ReaderShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshFeedIntent(),
            phrases: [
                "Refresh my feed in \(.applicationName)",
                "Get new articles in \(.applicationName)"
            ],
            shortTitle: "Refresh Feed",
            systemImageName: "arrow.clockwise"
        )

        AppShortcut(
            intent: OpenArticleIntent(),
            phrases: [
                "Open an article in \(.applicationName)"
            ],
            shortTitle: "Open Article",
            systemImageName: "doc.text"
        )
    }
}
```

Exactly one `AppShortcutsProvider` per app. It's a static declaration and gets scanned at build time.

## The `\(.applicationName)` rule

Every phrase must include `\(.applicationName)` somewhere:

```swift
// WRONG - build error: "Every app shortcut phrase needs to contain the applicationName"
phrases: ["Refresh my feed"]

// CORRECT
phrases: ["Refresh my feed in \(.applicationName)"]
```

This is enforced by the macro at compile time. The reason: without the app name, phrases collide with other apps' commands. "Set a timer for 5 minutes" belongs to the Clock app; your app can't hijack it.

There's no way around this - never hard-code the name string. The interpolation expands to the bundle's display name and keeps working after app renames.

## Phrase coverage

On iOS 17+, Siri has **flexible matching** - a build-time semantic similarity index matches close paraphrases ("Tell me the summary of my groceries list" → "Summarize my groceries list"). It's on by default when you build with Xcode 15+; disable via the `Enable App Shortcuts Flexible Matching` build setting if you need exact-match only.

Even with flexible matching, provide multiple wordings. The index matches meaning; providing varied phrasings makes it more likely to converge on your intent for ambiguous speech.

```swift
AppShortcut(
    intent: AppendNoteIntent(),
    phrases: [
        "Append to my latest note in \(.applicationName)",
        "Add to my most recent note in \(.applicationName)",
        "Save this to \(.applicationName)"
    ],
    shortTitle: "Append to Latest Note",
    systemImageName: "plus"
)
```

Short, natural forms beat long, formal ones. Think of what a user would actually say aloud.

## Titles vs short titles

`AppIntent.title` and `AppShortcut.shortTitle` are different and both shown:

- `title` appears in the Shortcuts action list when a user builds a multi-action shortcut (e.g., "Refresh feed").
- `shortTitle` appears as the action button tile in Shortcuts home, in the app's Shortcut gallery, and in Siri's "what can I do here" sheet.

Give them different-enough wording during development ("Count Recent Dreams" vs "Recent Dream Count") to see which surface is which; settle on consistent phrasing before shipping.

## Parameterising an `AppShortcut`

`AppShortcut` can be configured by the intent's `@Parameter`s - this lets one intent surface several ready-made phrases:

```swift
AppShortcut(
    intent: SearchArticlesIntent(),
    phrases: [
        "Search \(\.$query) in \(.applicationName)",
        "Find \(\.$query) in \(.applicationName)"
    ],
    shortTitle: "Search",
    systemImageName: "magnifyingglass"
)
```

`\(\.$query)` is a parameter key path - the user's utterance fills it in.

### Refreshing parameter-driven phrases: `updateAppShortcutParameters()`

When a phrase uses a key path to an entity parameter (e.g., `\(\.$folder)`), the system caches the list of candidate values it will show. When your underlying entity data changes - a new folder is added, a bookmark is renamed - call `updateAppShortcutParameters()` to invalidate the cache:

```swift
@main
struct ReaderApp: App {
    init() {
        ReaderShortcuts.updateAppShortcutParameters()

        let store = DataStore(...)
        self._store = .init(initialValue: store)
        AppDependencyManager.shared.add(dependency: store)
    }
    ...
}
```

In UIKit-lifecycle apps, call it from `application(_:didFinishLaunchingWithOptions:)` instead:

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        ReaderShortcuts.updateAppShortcutParameters()
        return true
    }
}
```

Call it:

- Once at launch (`App.init()` in SwiftUI, `didFinishLaunching` in UIKit) to seed the current set.
- Again whenever an entity that appears in a shortcut phrase key path changes (creation, rename, deletion).

Without this, Siri-suggested phrases can point at stale entity names or offer deleted items.

### Negative phrases (iOS 17+)

When flexible matching produces false positives, add phrases that should **not** trigger the shortcut:

```swift
AppShortcut(
    intent: DeleteFolderIntent(),
    phrases: [
        "Delete folder in \(.applicationName)"
    ],
    negativePhrases: [
        "Delete folder permanently in \(.applicationName)",
        "Empty trash in \(.applicationName)"
    ],
    shortTitle: "Delete Folder",
    systemImageName: "trash"
)
```

Catches common near-matches the semantic index would otherwise flag. Keep the list short - each negative phrase costs one of your 1,000 total phrase slots.

## `AppShortcuts` String Catalog

Localizing Swift-declared phrases used to be constrained: each locale had to have the same number of phrases as the Swift source. iOS 17+ adds a dedicated **AppShortcuts** String Catalog type that lifts this limit - different locales can have different phrasing counts, and new phrases can be added per-locale without touching Swift code.

Xcode's migration assistant converts existing `AppShortcuts.strings` files to the catalog format. All new projects should start with the catalog.

## Previewing shortcuts in Xcode

Xcode 15+ (macOS Sonoma) has `Product > App Shortcuts Preview`, a tool that lets you test phrase matching and flexible-match behavior without rebuilding, speaking to Siri, or leaving the IDE. It supports switching locales, so you can verify translations in-place.

Use it heavily when tuning phrases - it's far faster than the simulator round-trip.

## Accent colors for Spotlight and Shortcuts

iOS 17+ lets you style the app's appearance in Spotlight cards and the Shortcuts library through two `Info.plist` keys:

- `NSAppIconActionTintColorName` - primary tint, applied to icons and buttons.
- `NSAppIconComplementingColorNames` - array of up to two complementary colors the system can layer into backgrounds.

Both values reference color names from the app's asset catalog. The system picks which complementing color to use based on context.

## `shortcutTileColor`

```swift
static let shortcutTileColor: ShortcutTileColor = .navy
```

Options: `.grayBlue`, `.red`, `.orange`, `.yellow`, `.green`, `.teal`, `.blue`, `.indigo`, `.purple`, `.pink`, `.navy`, `.lightBlue`, `.gray`, `.lime`. The color is used by the Shortcuts app for the app's tiles.

## In-app discoverability

Two SwiftUI helpers nudge users toward shortcuts right inside your app.

### `ShortcutsLink`

Opens directly to the app's page in the Shortcuts app:

```swift
import AppIntents

var body: some View {
    Section {
        ...
    } footer: {
        ShortcutsLink()
    }
}
```

One line. No parameters. Fine to place in a Settings screen, an onboarding sheet, or a list footer.

### `SiriTipView`

Suggests a specific Siri phrase for one of your intents:

```swift
@AppStorage("suggest.refreshFeed") var showTip = true

SiriTipView(intent: RefreshFeedIntent(), isVisible: $showTip)
```

When `isVisible` is bound, the tip has an 'x' to dismiss it - persist the dismissal through `@AppStorage` so it doesn't re-appear. The displayed phrase is read from the intent's registered `AppShortcut` phrases.

### "What can I do here?"

On a real device, saying "what can I do here?" to Siri asks the OS to scan the current app's registered intents and show them. This works automatically once your `AppShortcutsProvider` is registered - no extra code needed. It's a powerful discoverability lever for users who already know Siri exists.

## Presenting intent parameters

`AppShortcut` takes an optional `parameterPresentation` to change how Shortcuts renders parameter pickers for that specific phrase. Use it to pre-fill parameter labels or example values. It's sparsely documented; reach for it only when default rendering is insufficient.

## Debugging in the simulator

Siri voice activation in the simulator is noticeably unreliable. If a phrase that worked yesterday stops working today:

- **Erase and reinstall.** Device → Erase All Content and Settings often clears cached phrase registrations that got stale.
- **Retry several times.** Voice recognition on the simulator can fail on the first or second attempt even when correctly configured.
- **Switch to typed Siri.** Settings → Accessibility → Siri → Type to Siri. Bypasses voice recognition entirely; proves whether the issue is speech or intent wiring.
- **Use Xcode's App Shortcuts Preview tool** (macOS Sonoma + Xcode 15+). It tests phrase matching directly, with no voice path at all.
- **Check the App Shortcuts Preview metadata warnings.** The tool reports when phrases fail the `\(.applicationName)` validation or other macro-enforced rules.

On-device is generally more reliable than the simulator for end-to-end Siri testing. When simulator behavior is inconsistent and on-device works, trust the device.

## Platform-specific behavior

### watchOS

App Shortcuts from a paired iPhone do **not** sync to Apple Watch. The watchOS app must be installed separately and declare its own `AppShortcutsProvider`. Flexible Matching is unavailable on Watch - phrases are exact-match. iOS 16+ / watchOS 9.2+ for basic support.

### HomePod

iOS 16.2+ / HomePod Software 16.2+. Voice-only - there's no screen, so any result your intent returns is spoken. The `IntentDialog(full:supporting:)` pattern matters especially here:

```swift
let dialog = IntentDialog(
    full: "You have 3 reminders due this afternoon: call Alex, buy milk, pay electric bill.",
    supporting: "3 reminders due today."
)
```

HomePod speaks the `full` string; screen-capable devices render the `supporting` string alongside any snippet. Always provide both when the intent might run on HomePod.

Voice-only devices won't launch the app, even if `openAppWhenRun = true`. Intents that *must* open the app to succeed will fail audibly on HomePod - guard against this or document the limitation.

## What NOT to register

- Do not register intents you only want to use as widget configuration. Widget-configuration intents (`WidgetConfigurationIntent`) are resolved through widget kit, not through `AppShortcutsProvider`.
- Do not register intents meant solely as building blocks for other intents - keep them internal.
- If an intent should only run inside your own app code (e.g., from a button), you don't have to register it at all. Registration is the publication step to the rest of the system.
