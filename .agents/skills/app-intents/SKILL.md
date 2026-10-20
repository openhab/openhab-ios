---
name: app-intents
description: Writes and reviews Swift App Intents code that exposes app actions and data to Siri, Shortcuts, Spotlight, widgets, Control Center, and Apple Intelligence. Use when adding AppIntent, AppEntity, OpenIntent, AppShortcutsProvider, EntityQuery, Focus Filters, AssistantEntity/AssistantIntent schemas, on-screen awareness, LongRunningIntent/CancellableIntent, EntityCollection, SyncableEntity, AppIntentsTesting, or when wiring SwiftData/networked data into intents.
license: MIT
metadata:
  author: Anton Novoselov
  version: "1.3.0"
---

Write and review Swift code that exposes app functionality through the App Intents framework, ensuring correct protocol conformance, safe data flow, and idiomatic discoverability wiring.

Review process:

1. Check intent fundamentals (protocol, `perform()`, return types, dialog) using `references/fundamentals.md`.
1. Validate parameters and parameter options using `references/parameters.md`.
1. Validate entity types, display representations, and queries using `references/entities.md`.
1. Check the `AppShortcutsProvider` registration and discoverability UI using `references/shortcuts-and-siri.md`.
1. Validate `OpenIntent` navigation and snippet view return types using `references/open-and-snippet-intents.md`.
1. Check dependency injection and the data-controller pattern using `references/dependencies.md`.
1. Validate Spotlight indexing via `IndexedEntity`, `IndexedEntityQuery`, and attribute sets using `references/spotlight.md`.
1. Check `@AssistantEntity` / `@AssistantIntent` schema adoption using `references/assistant-schemas.md`.
1. Validate the Siri / Apple Intelligence integration (finding content, custom responses, donations, confirmation, ownership) using `references/siri-intelligence.md`.
1. Check on-screen awareness and content transfer (view annotations, `IntentValueRepresentation`, system-integration annotations) using `references/onscreen-awareness.md`.
1. For intents that run past 30 seconds, handle cancellation, or target a specific process, use `references/long-running-and-execution.md`.
1. If writing or reviewing tests for intents, use `references/testing-intents.md` (covers the new `AppIntentsTesting` framework).
1. Catch common mistakes using `references/anti-patterns.md`.

If doing partial work, load only the relevant reference files.


## Task-based routing

Match the user's goal to the read order. Load only what you need.

### "Create my first App Intent"
1. `references/fundamentals.md` - protocol, `perform()`, return types
2. `references/shortcuts-and-siri.md` - register it so it shows up

### "Add a parameter the user picks in Shortcuts"
1. `references/parameters.md` - `@Parameter`, prompts, disambiguation
2. `references/entities.md` - if the parameter is a domain entity

### "Make my app's data searchable from Siri / Spotlight"
1. `references/entities.md` - `AppEntity`, `IndexedEntity`, `@Property`
2. `references/spotlight.md` - indexing strategies, attribute sets
3. `references/shortcuts-and-siri.md` - flexible matching, phrase rules

### "Show a summary / interactive view when Siri runs my intent"
1. `references/open-and-snippet-intents.md` - inline vs indirect snippets, `SnippetIntent`, `Button(intent:)`
2. `references/fundamentals.md` - return types and snippet design rules

### "Open a specific thing in my app from Siri / Shortcuts"
1. `references/open-and-snippet-intents.md` - `OpenIntent`, `URLRepresentableIntent`, `TargetContentProvidingIntent`
2. `references/dependencies.md` - navigator / scene routing

### "Bring my app's content and actions to Siri / Apple Intelligence"
1. `references/siri-intelligence.md` - the integration model, finding content (semantic index / structured search / in-app search), custom responses, donations, confirmation/ownership
2. `references/assistant-schemas.md` - schema macros, domains, multi-schema requirements, Xcode snippets
3. `references/onscreen-awareness.md` - view annotations, content transfer, system-integration annotations

### "Integrate with Apple Intelligence"
1. `references/assistant-schemas.md` - schema macros, domains, Use Model action, onscreen content
2. `references/entities.md` - `@Property`, `Transferable` (required for several schemas)

### "Let Siri understand what's on screen"
1. `references/onscreen-awareness.md` - the 4 annotation APIs, content transfer, `displayRepresentations` fast path, annotations on notifications/Now Playing/AlarmKit
2. `references/siri-intelligence.md` - how onscreen context fits the larger Siri story

### "Make my intent run longer than 30 seconds or target a process"
1. `references/long-running-and-execution.md` - `LongRunningIntent`, `CancellableIntent`, `allowedExecutionTargets`, background GPU
2. `references/fundamentals.md` - `ProgressReportingIntent`, `supportedModes`

### "Handle large numbers of entities efficiently / sync across devices"
1. `references/parameters.md` - `EntityCollection` (identifiers-only parameters)
2. `references/entities.md` - `SyncableEntity` for cross-device identity, `RelevantEntities` for proactive suggestions

### "Support Visual Intelligence / image search"
1. `references/assistant-schemas.md` - `IntentValueQuery`, `SemanticContentDescriptor`, `@UnionValue`
2. `references/entities.md` - `Transferable` + `OpenIntent` pairing

### "Build an interactive widget or Control Center control"
1. `references/open-and-snippet-intents.md` - `Button(intent:)`, `WidgetConfigurationIntent`, `ControlConfigurationIntent`, `ControlWidgetButton`
2. `references/dependencies.md` - App Group shared storage, process boundaries

### "Structure my app around App Intents"
1. `references/fundamentals.md` - intents as canonical action layer
2. `references/dependencies.md` - `@Dependency`, cross-module `AppIntentsPackage`
3. `references/entities.md` - entity-as-bridge pattern

### "Test my App Intents"
1. `references/testing-intents.md` - the `AppIntentsTesting` framework (out-of-process integration), direct struct unit tests, mocking `@Dependency`, test-only intents, what you can't test

### "I'm hitting build errors or runtime bugs"
1. `references/anti-patterns.md` - 35+ catches with before/after fixes


## Decision trees

Quick orientation when you know the task but not the right API.

### Which intent protocol should I conform to?

```
Generic action?
  → AppIntent

Opens the app to a specific entity?
  → OpenIntent (+ TargetContentProvidingIntent on iOS)
  → on iOS 27+, @AppIntent(schema: .system.open) on the OpenIntent, with a legacy sibling intent for older OS

Renders an interactive view only, no business logic?
  → SnippetIntent

Needs to bring the app forward conditionally?
  → AppIntent with supportedModes (iOS 26+)
  → or ForegroundContinuableIntent (iOS 17-18)

Runs longer than 30 seconds (upload, sync, inference)?
  → LongRunningIntent + performBackgroundTask (iOS 27+)

Needs to clean up gracefully when cancelled (with the reason)?
  → CancellableIntent + withIntentCancellationHandler (iOS 26.4+)

Deletes entities with standard confirmation?
  → DeleteIntent

Routes a search query into the app?
  → ShowInAppSearchResultsIntent

Backs widget configuration?
  → WidgetConfigurationIntent (empty conformance, no perform)

Backs a Control Center control?
  → ControlConfigurationIntent

Has a universal-link URL representation?
  → URLRepresentableIntent + OpenIntent (no perform needed)

Matches an Apple Intelligence domain?
  → AppIntent + @AppIntent(schema: .domain.action)
```

### Which entity type should I use?

```
Fixed set known at compile time?
  → AppEnum

Dynamic data with a persistent id?
  → AppEntity

Entity must appear in Spotlight?
  → AppEntity + IndexedEntity

Entity IS a file (scan, voice memo, exported image)?
  → FileEntity

Computed / aggregated data with no stable id?
  → TransientAppEntity

Needs Apple Intelligence schema awareness?
  → AppEntity + @AppEntity(schema: .domain.type)

Supports cross-app sharing?
  → AppEntity + Transferable
```

### Which query should my entity use?

```
Small fixed set, enumerable?
  → EnumerableEntityQuery (also gets a basic Find intent)

Large dataset, searchable by name?
  → EntityQuery + EntityStringQuery

Many queryable properties, user should build predicates?
  → EntityPropertyQuery (auto-generates Find intent with comparators + sort)

Simple id-only lookup, no search?
  → UniqueIDEntityQuery

Indexed in Spotlight and want reindexing support?
  → IndexedEntityQuery (iOS 27+)

Structured Siri search you can't index ahead of time?
  → IntentValueQuery (structured input, returns 1+ entity types via @UnionValue)

Visual intelligence / image search?
  → IntentValueQuery + SemanticContentDescriptor
```

### How should Siri find my content?

```
Content is local and indexable?
  → IndexedEntity + indexAppEntities (semantic index) - the primary path
  → add IndexedEntityQuery for reindexing support (iOS 27+)

Too large / server-side / too volatile to index?
  → IntentValueQuery (structured search input)

User wants to search inside your own UI?
  → @AppIntent(schema: .system.searchInApp) + ShowInAppSearchResultsIntent

Content nobody has found or used yet, but relevant right now?
  → RelevantEntities.updateEntities(_:for:) (iOS 27+)

Teach the system how people use the app (patterns)?
  → IntentDonationManager (donate UI interactions)
```

### Which property wrapper should I use on entity fields?

```
Stored on the entity struct, should appear in Shortcuts/Find/summary?
  → @Property

Derived from an underlying model object (cheap to compute)?
  → @ComputedProperty (preferred over @Property for wrappers around models)

Derived AND should be indexed in Spotlight?
  → @ComputedProperty(indexingKey: \.keyName)

Expensive to compute (network, ML inference, heavy query)?
  → @DeferredProperty (async getter, only runs when system asks)

Internal to the entity, not shown anywhere?
  → plain stored property (no wrapper)
```


## Core Instructions

- Target iOS 16+ / macOS 13+ minimum for App Intents. `IndexedEntity`, `OpenIntent`, focus filters, and control widgets require iOS 16+; `@AssistantEntity` / `@AssistantIntent` schemas require iOS 18.2+; anchored relative date styles and many assistant schemas require iOS 18.4+. The **27 releases** (WWDC 2026, iOS 27 / macOS 27) add `LongRunningIntent`, `EntityCollection`, `SyncableEntity`, `RelevantEntities`, `IndexedEntityQuery`, `OwnershipProvidingEntity`, `allowedExecutionTargets`, the `AppIntentsTesting` framework, and native `Duration`/`PersonNameComponents` parameters; `CancellableIntent` and `IntentValueRepresentation` are iOS 26.4+; `supportedModes` is iOS 26+. Apple's own naming for the WWDC 2026 cohort is "the 27 releases" - use that, not "iOS 19".
- **Never** make a SwiftData `@Model` class or other reference-type data model conform to `AppEntity`. `AppEntity` requires `Sendable`; `@Model` classes are not sendable. Create a separate `struct` entity that shadows the fields you want to expose.
- **Never** pass `ModelContext` across actor boundaries. `ModelContext` is not sendable. Pass `ModelContainer` (which is sendable) and create a local context inside the actor that needs one.
- **Never** expose an intent to Siri/Spotlight only by writing its type, always register it through an `AppShortcutsProvider`. Types not registered there will not appear in Shortcuts, Siri suggestions, or the action button picker.
- **Never** write a Siri activation phrase without interpolating `\(.applicationName)`. The App Intents macro rejects phrases without it at compile time, because phrases without the app name would collide with other apps' commands.
- **Never** reach back into a SwiftUI `@Query` from inside an intent. `@Query` only works inside a `View`. Run a one-shot `FetchDescriptor` through a `ModelContext` instead, or route through a centralized data controller.
- **Never** instantiate services, data stores, or authentication managers inside `perform()`. Inject them through `@Dependency` and register them once in `App.init()` with `AppDependencyManager.shared.add(dependency:)`.
- **Never** use `String(format:)` or manual concatenation for localized intent dialog. Use `LocalizedStringResource`, and use Foundation's grammar-agreement markdown (`^[\(count) item](inflect: true)`) inside an `AttributedString` for pluralization.
- When an intent can fire before the app's store / navigation exists (cold launch, splash, store built in the root view), dispatch through a main-actor router that queues the action until the UI attaches, and send Spotlight `CSSearchableItemActionType` user activities through the same action. See `references/open-and-snippet-intents.md`.
- Prefer `OpenIntent` for "take me to this thing" actions, `AppIntent & ShowsSnippetView` for self-contained one-shot summaries, and `AppIntent & ShowsSnippetIntent` + a paired `SnippetIntent` when the snippet contains `Button(intent:)` and needs to re-render after buttons fire.
- Always set `static let isDiscoverable: Bool = false` on helper intents that only back a widget button, snippet button, or other intent - otherwise they pollute the user's Shortcuts library.
- When an intent mutates data that widgets or control widgets display, call `WidgetCenter.shared.reloadAllTimelines()` inside `perform()` before returning.
- When `Button(intent:)` lives inside a widget view, share state between the intent (runs in the app process) and the widget's timeline provider (runs in the extension process) via App Group `UserDefaults(suiteName:)` or a shared `ModelContainer` URL - never `UserDefaults.standard` or in-memory `@Dependency` state.
- When entity data that appears in a shortcut phrase's key path changes (creation, rename, deletion), call `YourShortcutsProvider.updateAppShortcutParameters()` to invalidate the cached candidate list.
- Prefer `EnumerableEntityQuery` when the whole set is small and cheap to load; implement `EntityQuery` + `EntityStringQuery` when the dataset is large or searchable; add `EntityPropertyQuery` to get a system-generated Find intent for free. `entities(for identifiers:)` is mandatory on every query; without it, parameter resolution breaks.
- Mark entity fields that users might filter, sort, or reference in parameter summaries with `@Property` (stored) or `@ComputedProperty` (derived). Plain stored properties are invisible to the App Intents framework.
- Use `TransientAppEntity` for return data that's computed on the fly (summaries, aggregates). Don't try to shoehorn it into `AppEntity` with a fake id.
- When the entity already has a universal-link URL, conform it to `URLRepresentableEntity` and conform the open intent to `URLRepresentableIntent` - the system routes opens through your existing link handler without a `perform()`.
- For entities visible onscreen that Siri should be able to understand, combine `.userActivity(_:element:)` on the view with `Transferable` conformance on the entity. Identification alone is not enough; Siri needs exportable content.
- `SnippetIntent.perform()` is called multiple times per user interaction (initial show, after each button tap, on appearance changes, on `reload()`). Keep it pure: read state, assemble the view, return. Never mutate app state or kick off slow work inside a snippet intent's `perform()`.
- Respect hard limits: 10 `AppShortcut`s per app, 1000 total trigger phrases (including parameter expansions). The first phrase in each shortcut's array is the primary one - it's shown on the Shortcuts home tile and as Siri's "what can I do with X?" answer.
- Include at least one non-parameterized phrase per App Shortcut so it's discoverable before first launch; parameterized phrases don't appear in Spotlight until the app has run once and populated the parameter cache.
- Prefer `supportedModes` + `continueInForeground` (iOS 26+) over `ForegroundContinuableIntent` / `needsToContinueInForegroundError` for new code that conditionally foregrounds. The newer form lets one intent declare it may run background or foreground based on runtime state.
- Snippet views have a 340-point height ceiling; beyond this, scrolling breaks the glance overlay model. Link to the full app for deep content, and keep snippet text larger than system defaults for legibility at reading distance.
- For text parameters that may receive input from Apple Intelligence's Use Model action, declare the type as `AttributedString` rather than `String` so rich formatting (bold, italic, lists, tables) is preserved losslessly.
- The app's `App` struct initializer is executed when an intent runs, even if the UI never appears. Do all intent-relevant setup (`ModelContainer` creation, `AppDependencyManager.shared.add(...)`, log plumbing) inside `init()`, not inside view modifiers like `.task` or `.onAppear`.
- `LocalizedStringResource` is the standard string type everywhere in App Intents (titles, dialog, parameter prompts). It shares string catalogs with SwiftUI, so localization works out of the box.
- Grammar agreement (`inflect: true`) works in English, French, German, Italian, Spanish, and Portuguese (both variants). For other locales it falls back to the unmodified form.
- Intents triggered from a system surface get ~30 seconds (no hard limit on macOS). For uploads, sync, large file ops, or on-device inference, conform to `LongRunningIntent` and do the work inside `performBackgroundTask { ... }` - and **report `progress` regularly**, because going quiet makes the system revoke the runtime extension. Pair with `CancellableIntent` to clean up with the cancellation reason. Don't try to beat the limit with a detached `Task`; unmanaged tasks aren't covered by the extension.
- Use `EntityCollection<Entity>` instead of `[Entity]` for parameters that may hold many entities when `perform()` mostly needs ids - it skips full entity resolution during parameter handling. Call `resolvedEntities()` only when you need the full objects.
- In schema-based **update** intents, distinguish "don't change" from "clear" with `$parameter.valueState` (`.set(value)` / `.set(nil)` / `.unset`), not a plain `nil` check - otherwise voice commands can never clear a field.
- Conform entities to `SyncableEntity` when Siri might reference them in a cross-device conversation. If the id is already consistent everywhere (server UUID, CloudKit record id), just adopt the protocol; otherwise pair local and stable ids with `SyncableEntityIdentifier`.
- Conform shareable entities to `OwnershipProvidingEntity` and keep their `ownership` (`.shared` / `.public`) current, so Siri confirms actions on content the user shared or published. By default Siri assumes entities are private and may skip confirmation.
- To carry structured types other apps understand (a coordinate, a contact, a name), add an `IntentValueRepresentation` via the `ValueRepresentation` builder to the entity's `transferRepresentation` - `FileRepresentation`/`DataRepresentation` only cover file formats. Use the key-path form (`ValueRepresentation(exporting: \.place)`) when the entity already stores the system type.
- For on-screen awareness, pick the annotation by shape: `.userActivity` for one primary item, `.appEntityIdentifier(_:)` for one among a few, `.appEntityIdentifier(forSelectionType:)` on a `List`/collection for many (lazy), `.appEntityUIElements(_:)` for custom `Canvas`/`CALayer` drawing. Annotations on Notifications, Now Playing, and AlarmKit require a real `AppEntity` - `TransientAppEntity` has no persistent id and can't be used there. Add a `displayRepresentations` query method so Siri can resolve onscreen entities without a full DB fetch.
- Donate **UI** interactions with `IntentDonationManager` (the system already donates Siri/Shortcuts runs); donate after the action completes, don't over-donate (the system will start ignoring you), and delete stale donations.
- Test with the `AppIntentsTesting` framework (out-of-process, in an XCUITest bundle) for the integration surface - intents, queries, `spotlightQuery()`, `viewAnnotations()`; use test-only intents (`isDiscoverable = false` + `#if DEBUG`) to seed data and reach internal state. Keep direct `perform()` struct tests for pure logic.


## Output Format

If the user asks for a review, organize findings by file. For each issue:

1. State the file and relevant line(s).
2. Name the anti-pattern being replaced.
3. Show a brief before/after code fix.

Skip files with no issues. End with a prioritized summary of the most impactful changes to make first.

If the user asks you to write or fix intent code, make the changes directly instead of returning a findings report.

Example output:

### RecentItemsIntent.swift

**Line 18: SwiftData `@Model` cannot conform to `AppEntity` (not `Sendable`).**

```swift
// Before
extension Article: AppEntity { ... }

// After
struct ArticleEntity: AppEntity {
    var id: UUID
    var title: String
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Article"
    static let defaultQuery = ArticleEntityQuery()
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}
```

**Line 42: Siri phrase missing `\(.applicationName)` - will fail to build.**

```swift
// Before
AppShortcut(intent: OpenArticleIntent(), phrases: ["Open an article"], ...)

// After
AppShortcut(intent: OpenArticleIntent(), phrases: ["Open an article in \(.applicationName)"], ...)
```

### Summary

1. **Sendability (high):** `Article` as `AppEntity` will fail to compile on Swift 6; create a shadow struct.
2. **Siri phrases (high):** `\(.applicationName)` is required in every phrase.

End of example.


## References

- `references/fundamentals.md` - `AppIntent` protocol, `perform()`, return types (`IntentResult`, `ProvidesDialog`, `ReturnsValue`, `ShowsSnippetView`, `OpensIntent`), intent dialog, grammar agreement.
- `references/parameters.md` - `@Parameter`, primitive vs entity parameters, `@AppEnum`, dialog options, parameter prompts.
- `references/entities.md` - `AppEntity`, `IndexedEntity`, shadow-struct pattern, display representations, entity queries (`EnumerableEntityQuery`, `EntityQuery`, `EntityStringQuery`, `UniqueIDEntityQuery`).
- `references/shortcuts-and-siri.md` - `AppShortcutsProvider`, phrases (`\(.applicationName)` rule), `shortcutTileColor`, `SiriTipView`, `ShortcutsLink`, parameter presentation.
- `references/open-and-snippet-intents.md` - `OpenIntent`, snippet views (`ShowsSnippetView`), navigation via data controller, when to use which.
- `references/dependencies.md` - `@Dependency`, `AppDependencyManager`, data-controller pattern, `ModelContainer` vs `ModelContext` sendability, main-actor vs local-context tradeoff.
- `references/spotlight.md` - `IndexedEntity`, `IndexedEntityQuery` (reindexing), `CSSearchableIndex`, `attributeSet`, semantic index, index-on-launch vs index-on-change, debounced reindexing.
- `references/assistant-schemas.md` - `@AssistantEntity`, `@AssistantIntent`, schema adoption, multi-schema requirements, `.system.searchInApp`, Visual Intelligence (iPad/macOS, system stores), Xcode code snippets, caveats.
- `references/siri-intelligence.md` - the Siri / Apple Intelligence integration model: finding content (semantic index / structured search / in-app search), custom responses, interaction donations, confirmation + `OwnershipProvidingEntity`, validation flow.
- `references/onscreen-awareness.md` - the 4 on-screen annotation APIs, content transfer (`IntentValueRepresentation`, resolve vs import), `displayRepresentations` fast path, entity annotations on Notifications / Now Playing / AlarmKit.
- `references/long-running-and-execution.md` - the 30-second budget, `LongRunningIntent` + `performBackgroundTask`, `CancellableIntent`, background GPU, `allowedExecutionTargets`.
- `references/testing-intents.md` - the `AppIntentsTesting` framework (out-of-process integration), direct `perform()` unit tests, mocking `@Dependency` via `AppDependencyManager`, test-only intents, what you can't unit-test.
- `references/anti-patterns.md` - common mistakes LLMs make when generating App Intents code.
