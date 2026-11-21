# Parameters

Intent parameters are declared with `@Parameter` and are automatically resolved by the system - the user is prompted, taps a picker, or chains a value from another action in Shortcuts.

## Declaring a parameter

```swift
struct AppendToNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Append to note"

    @Parameter(title: "Text")
    var newText: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // newText is guaranteed non-nil here
        ...
    }
}
```

By the time `perform()` runs, every non-optional `@Parameter` is filled. If the user didn't provide one, the system asked them - via Siri voice, a text field, or a picker - before calling `perform()`.

On Xcode 16+, `title:` is optional. If omitted, the system auto-generates a localizable title from the property name (`newText` → "New Text"). Specify `title:` only when you want something different from the derived form.

## Required vs optional parameters

Design guidance: keep parameters **optional** unless the intent is genuinely useless without them.

- Optional parameters let the intent run immediately with sensible defaults; the user only gets a follow-up prompt when they didn't supply a value explicitly.
- Required parameters always trigger a prompt before `perform()` runs - even in Shortcuts, where the user just configured the shortcut and knows what they want.

For boolean parameters, set a default that reflects the common case (`default: true`). For a toggle intent, default to the value the toggle ends up at - e.g., a "Set Do Not Disturb" intent defaults `enabled: true`.

### Optional in update intents: "don't change" vs "clear" via `valueState`

For an **update** intent, an optional parameter being `nil` is ambiguous: does `nil` mean "leave this field alone" or "explicitly clear it"? A plain `nil` check can't tell them apart. The `@AppIntent` macro wraps each parameter in an `IntentParameter` exposing a `valueState`, which distinguishes the three cases:

```swift
struct UpdateEventIntent: AppIntent {
    @Parameter var event: EventEntity
    @Parameter var recurrence: Calendar.RecurrenceRule?
    // ...

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<EventEntity> {
        switch $recurrence.valueState {
        case .set(let rule?):  try store.setRecurrence(rule, on: event.id)   // new value provided
        case .set(nil):        try store.clearRecurrence(on: event.id)        // explicitly cleared
        case .unset:           break                                          // not part of the request - leave alone
        }
        // ...
    }
}
```

`$parameter.valueState` is `.set(value)` (with a non-nil value = new value, with `nil` = explicitly cleared) or `.unset` (the parameter wasn't part of the request). Reach for it on any optional parameter where clearing the value is a meaningful, distinct action from not touching it - typical in schema-based update intents (`calendar_updateEvent`, etc.) where most parameters are optional.

## Supported parameter types

Primitive:

- `String`, `Int`, `Double`, `Bool`, `Date`, `URL`, `Measurement`
- `IntentFile`, `IntentItem`, `IntentEnum`
- `Decimal`, `Data`
- `Duration`, `PersonNameComponents` (and more) - **native types added in the 27 releases**
- Optional or array of any of the above

Domain types:

- Any `AppEntity` (single or `[MyEntity]`)
- Any `AppEnum`
- An `EntityCollection<MyEntity>` (identifiers only - see below)
- A `@UnionValue` enum (one parameter, several entity types - see `entities.md`)

### Native types get pickers for free

When a parameter's type is one the system understands, declaring it is all you do - the system supplies a **native picker, Siri understanding, and localization** with no custom UI. The 27 releases extend that built-in support to more types: use `Duration` instead of hand-rolling a time picker, `PersonNameComponents` for structured name input instead of a plain `String`. Each works everywhere the intent does - Siri, Shortcuts, widgets.

## Parameter options

`@Parameter` accepts options that shape the user-facing prompt:

```swift
@Parameter(
    title: "Tag",
    description: "Tag applied to the bookmark.",
    requestValueDialog: "Which tag should I use?",
    default: "reading"
)
var tag: String

@Parameter(
    title: "Priority",
    default: .normal,
    requestDisambiguationDialog: "Which priority?"
)
var priority: PriorityLevel  // an AppEnum

@Parameter(title: "Attachment", supportedTypeIdentifiers: ["public.image", "public.pdf"])
var attachment: IntentFile
```

### Auto-chaining in Shortcuts: `inputConnectionBehavior`

When an intent is likely to run *after* another action in a Shortcuts workflow, declare that the parameter should auto-wire to the previous result:

```swift
@Parameter(
    title: "Image",
    supportedTypeIdentifiers: ["public.image"],
    inputConnectionBehavior: .connectToPreviousIntentResult
)
var image: IntentFile
```

Shortcuts will then default the field to "Image from [previous action]" when the user drops this action into a workflow. The user can still override; the attribute just picks a better default.

Use `.connectToPreviousIntentResult` for parameters that are commonly the output of the preceding action (an image for a "Resize image" intent, an entity for a "Mark as favorite" intent). Leave the default for parameters where manual configuration is expected.

### Working with `IntentFile` parameters

`IntentFile` exposes three access paths:

```swift
func perform() async throws -> some IntentResult {
    // Path on disk - most common for writable or large-file operations
    if let url = image.fileURL {
        try await processor.convert(fileAt: url)
    } else {
        // Data in memory - when the file came from a transient source
        let data = try image.data(contentType: .image)
        try await processor.process(data: data)
    }
    return .result()
}
```

- `fileURL: URL?` - set when the file lives on disk (document picker, Files app). `nil` for transient data.
- `data(contentType:)` - fetches the underlying bytes; may load from disk or memory.
- `filename: String` - the file's display name.

Prefer `fileURL` when present to avoid double-loading large files into memory.

## Entity parameters

Any `AppEntity` can be a parameter. The system uses the entity's `defaultQuery` to populate a picker and to resolve user speech to a specific entity:

```swift
struct OpenBookmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "Open bookmark"

    @Parameter(title: "Bookmark")
    var bookmark: BookmarkEntity

    func perform() async throws -> some IntentResult {
        ...
    }
}
```

Given `BookmarkEntity.defaultQuery`, Shortcuts will show a "Bookmark" field with a picker populated from the query. In Siri, the user says "open bookmark Weather" and the system resolves "Weather" against the query's `EntityStringQuery` (if conformant) or falls back to a disambiguation dialog.

## `@AppEnum`

For fixed-set parameters, declare an `AppEnum`:

```swift
enum PriorityLevel: String, AppEnum {
    case low, normal, high

    static let typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: "Priority")
    static let typeDisplayName: LocalizedStringResource = "Priority"
    static let caseDisplayRepresentations: [PriorityLevel: DisplayRepresentation] = [
        .low: "Low",
        .normal: "Normal",
        .high: "High"
    ]
}
```

`typeDisplayRepresentation` and `typeDisplayName` look similar but serve different surfaces:

- `typeDisplayRepresentation` - used everywhere an entity/enum type is shown with a label and optional image (pickers, parameter cards).
- `typeDisplayName` - short `LocalizedStringResource`; used in inline contexts where only a plain label fits (Siri spoken prompts, parameter summaries).

Provide both on any enum or entity that will be user-facing. The initializer shorthand `.init(name: "Priority")` is equivalent to constructing a `TypeDisplayRepresentation` directly.

Enums show as nice pickers in Shortcuts, are speakable by Siri, and are chainable in automation.

## Parameter summaries

Give Shortcuts a one-line summary by implementing `parameterSummary`:

```swift
struct MoveArticleIntent: AppIntent {
    static let title: LocalizedStringResource = "Move article"

    @Parameter(title: "Article") var article: ArticleEntity
    @Parameter(title: "Folder") var folder: FolderEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Move \(\.$article) to \(\.$folder)")
    }

    func perform() async throws -> some IntentResult { .result() }
}
```

This renders as "Move [Article] to [Folder]" in the Shortcuts editor.

For intents with many parameters, `When`/`Switch` conditions tailor the summary to the inputs:

```swift
static var parameterSummary: some ParameterSummary {
    Switch(\.$action) {
        Case(.archive) { Summary("Archive \(\.$article)") }
        Case(.delete)  { Summary("Delete \(\.$article)") }
    }
}
```

### Nesting `Switch` / `Case` / `When` / `otherwise`

Real parameter summaries often branch on multiple axes. Nest conditions; the system picks the first branch that matches:

```swift
static var parameterSummary: some ParameterSummary {
    Switch(\.$activity) {
        Case(.biking) {
            When(\.$location, .hasAnyValue) {
                Summary("Show \(\.$activity) ideas within \(\.$searchRadius) of \(\.$location)")
            } otherwise: {
                When(\.$trailCollection, .hasAnyValue) {
                    Summary("Show \(\.$activity) ideas from \(\.$trailCollection)")
                } otherwise: {
                    Summary("Show \(\.$activity) ideas from \(\.$trailCollection) or near \(\.$location)")
                }
            }
        }
        DefaultCase {
            When(\.$location, .hasAnyValue) {
                Summary("Suggest \(\.$activity) trails within \(\.$searchRadius) of \(\.$location)")
            } otherwise: {
                Summary("Suggest \(\.$activity) trails from \(\.$trailCollection) or near \(\.$location)")
            }
        }
    }
}
```

Predicates that go inside `When`:

- `.hasAnyValue` - parameter has been set (non-nil, for optional parameters)
- `.equalTo(value)`, `.notEqualTo(value)`, `.lessThan(value)`, `.greaterThan(value)` - comparisons
- `.hasValue(.someEnumCase)` - enum case matching

Use `DefaultCase` to cover values not explicitly listed by `Case`.

## Context-aware option providers: `IntentParameterDependency`

A `DynamicOptionsProvider` or `EntityQuery` can read *other* parameters of the same intent by declaring them with `@IntentParameterDependency`. The options list then recomputes whenever the upstream parameter changes:

```swift
struct TrailsInRegionProvider: DynamicOptionsProvider {
    @IntentParameterDependency<SuggestTrailsIntent>(\.$region)
    var region

    func results() async throws -> [String] {
        guard let region else { return [] }
        return store.trailNames(in: region)
    }
}
```

Use this for cascading pickers: country → region → city; folder → note; playlist → song. Without `IntentParameterDependency`, the options provider runs in isolation and can't see sibling parameters.

iOS 17+. One provider can depend on multiple parameters and multiple parent intents.

## Array parameter size declarations

Array parameters can declare size limits per widget family, so the configuration UI asks for exactly the right number of items:

```swift
@Parameter(title: "Featured Routes", size: [
    .systemSmall: 1,
    .systemMedium: 3,
    .systemLarge: 5
])
var routes: [RouteEntity]
```

Inside a `WidgetConfigurationIntent`, this lets a single intent back multiple widget sizes. iOS 17+.

## Widget-family-conditional parameter summaries

`parameterSummary` can branch on the widget family being configured:

```swift
static var parameterSummary: some ParameterSummary {
    When(.widgetFamily, .equalTo, .systemLarge) {
        Summary("Show \(\.$routes) detailed routes")
    } otherwise: {
        Summary("Show \(\.$route)")
    }
}
```

Useful when a large widget exposes extra parameters a small widget doesn't need. iOS 17+.

## Requesting a value mid-perform

When a parameter is optional and you need it to continue, there are two mechanisms.

### `requestValue` - ask and receive inline

Prompt the user and `await` the result without re-entering `perform()`:

```swift
@Parameter(title: "Shots") var shots: EspressoShot?

func perform() async throws -> some IntentResult & ProvidesDialog {
    if shots == nil {
        shots = try await $shots.requestValue("How many shots?")
    }

    // shots is guaranteed non-nil here
    try store.log(shots!)
    return .result(dialog: "Done.")
}
```

This is the cleanest option when you need the value partway through a larger flow. The prompt happens inline, the user answers, execution continues.

### `needsValueError` - bail and let the system re-invoke

Throw to signal "I can't proceed without this"; the system re-prompts and calls `perform()` again from the top:

```swift
@Parameter(title: "Folder") var folder: FolderEntity?

func perform() async throws -> some IntentResult {
    guard let folder else {
        throw $folder.needsValueError("Which folder should the article go in?")
    }
    ...
}
```

Use this when there's no point doing any work without the value. Anything you did before the throw is discarded on re-invocation.

`requestValue` is newer and usually nicer ergonomically. `needsValueError` is older but still works, and is the only option if you want the system to record the prompt as a first-class "needs input" step in a Shortcuts automation.

### `needsValueError` re-runs the intent

When `needsValueError(...)` throws, the system prompts the user and then **calls `perform()` again from the top** - it doesn't resume from the throw point. Any side effects you performed before the throw run twice. Move side-effect work *after* parameter validation, or guard with idempotence checks.

`requestValue` and `requestConfirmation` don't restart; they suspend and resume inline.

## `requestChoice` for multiple options

iOS 26+. When you want to offer the user a pick between several alternatives (not a confirm/cancel), use `requestChoice`:

```swift
let options: [IntentChoice<Route>] = routes.map {
    IntentChoice(title: "\($0.name)", style: .default, value: $0)
}

let selected = try await requestChoice(
    actionName: .select,
    between: options,
    dialog: "Which route should we take?"
)

try await navigator.go(to: selected)
```

Returns the chosen option or throws if the user cancels. Rendered as a button row in the Shortcuts/Siri UI. Options accept `style: .destructive` for delete-style choices.

## Disambiguation

When a parameter has multiple plausible matches (e.g., two entities with similar names), present a disambiguation:

```swift
throw $folder.needsDisambiguationError(among: candidates, dialog: "Which folder?")
```

Keep disambiguation lists small (under ~5 items). Voice-only contexts (HomePod, CarPlay) read each option aloud - a 20-item list is unusable.

## `requestConfirmation` for suggested values

When the user provided a close-but-not-exact match and you want to confirm before proceeding, use `$parameter.requestConfirmation(for:dialog:)`:

```swift
if let location {
    let uniqueLocations = store.uniqueLocations
    if !uniqueLocations.contains(location) {
        let suggestedMatches = uniqueLocations.filter { $0.contains(location) }

        if suggestedMatches.count == 1 {
            let suggestion = suggestedMatches.first!
            let dialog = IntentDialog("Did you mean \(suggestion)?")
            let confirmed = try await $location.requestConfirmation(for: suggestion, dialog: dialog)
            if confirmed {
                self.location = suggestion
            } else {
                throw $location.needsValueError()
            }
        } else if suggestedMatches.count < 5 {
            let dialog = IntentDialog("Multiple locations match \(location). Did you mean one of these?")
            throw $location.needsDisambiguationError(among: suggestedMatches.sorted(), dialog: dialog)
        } else {
            throw $location.needsValueError(IntentDialog("No matches for \(location)."))
        }
    }
}
```

Three tiers: confirm one close match, disambiguate a small set, ask again from scratch. Pattern-match on the number of candidates to pick the right UX.

## `DynamicOptionsProvider` for primitive parameters

`AppEnum` handles fixed sets. `AppEntity` handles identifiable things with a query. What about a parameter that's a plain `String` but should be drawn from a runtime-computed list - like a set of location names loaded from the user's own data?

Provide a `DynamicOptionsProvider`:

```swift
struct LocationOptionsProvider: DynamicOptionsProvider {
    @Dependency var store: DataStore

    func results() async throws -> [String] {
        store.uniqueLocations.sorted(using: KeyPathComparator(\.self, comparator: .localizedStandard))
    }
}
```

Attach it to the parameter:

```swift
@Parameter(requestValueDialog: "Where would you like to go?",
           optionsProvider: LocationOptionsProvider())
var location: String?
```

Shortcuts now shows a picker populated by `results()`. The user can still type an arbitrary string (the parameter's type is `String`, not an enum) - validate their input inside `perform()` and use `requestConfirmation` / disambiguation to recover from near-misses.

`DynamicOptionsProvider` is right when:

- The values are a constrained list, not an open-ended string.
- The list is computed from the app's state (user-created tags, saved locations, recent recipients).
- The values aren't identifiable entities (just strings).

For identifiable domain objects, use `AppEntity` with an `EntityQuery` instead.

## Measurement parameter options

`Measurement` parameters accept unit and sign preferences:

```swift
@Parameter(defaultUnit: .kilometers, supportsNegativeNumbers: false)
var searchRadius: Measurement<UnitLength>?
```

- `defaultUnit:` - the unit Shortcuts initially selects. Users can still switch units, but this is the starting point and the unit stored when no explicit unit is provided.
- `supportsNegativeNumbers:` - disables the minus-sign toggle when the value is domain-nonsensical (a negative radius, a negative duration).

Convert explicitly inside `perform()` - users may configure the shortcut in one unit but your internal data may be stored in another:

```swift
if var searchRadius {
    searchRadius.convert(to: .meters)  // app stores data in meters
    results = results.filter { $0.distanceToTrail.value <= searchRadius.value }
}
```

## `@Parameter` vs ordinary property

Only `@Parameter`-annotated properties are exposed to the system. Ordinary properties are fine for local caching inside `perform()` but are invisible to Shortcuts, Siri, and the parameter-prompt system.

## Omitting `title:` on internal intents

For intents with `isDiscoverable = false` (helper intents that back a button, a snippet, or another intent), `@Parameter` without a `title:` is fine - no one will ever see the parameter UI:

```swift
struct LogAmountIntent: AppIntent {
    static let title: LocalizedStringResource = "Log caffeine amount"
    static let isDiscoverable: Bool = false

    @Parameter var amount: Int
    @Dependency var store: DataStore

    func perform() async throws -> some IntentResult {
        try store.log(Double(amount))
        return .result()
    }
}

extension LogAmountIntent {
    init(amount: Int) {
        self.amount = amount
    }
}
```

The trailing `init(amount: Int)` is what lets SwiftUI code write `Button(intent: LogAmountIntent(amount: 64))` (see `open-and-snippet-intents.md`). Always add it for intents that take parameters and back buttons - you can't pass a parameter any other way.

## Entity-to-entity relationships

Parameters can themselves be `AppEntity` arrays for bulk operations:

```swift
@Parameter(title: "Articles") var articles: [ArticleEntity]
```

Shortcuts renders this as a multi-select list; Siri asks "which articles?" and accepts multiple names.

## `EntityCollection` for large entity parameters (iOS 27+)

Before an intent runs, the system **fully resolves every entity parameter** - it calls your query to populate all properties so `perform()` has everything it might need. For a `[PhotoEntity]` parameter holding a thousand photos, that means resolving a thousand entities even if your code only needs their **ids** to update the data model. At scale, that's slow.

`EntityCollection<Entity>` stores the **identifiers** instead of resolved entities. As a parameter type, it tells the system *not* to resolve each id during parameter resolution - it just hands you the ids:

```swift
struct TagPhotosIntent: AppIntent {
    static let title: LocalizedStringResource = "Tag Photos"

    @Parameter(title: "Photos")
    var photos: EntityCollection<PhotoEntity>

    @Parameter(title: "Tag")
    var tag: String

    func perform() async throws -> some IntentResult {
        // Pass identifiers straight to the data layer - no hydration of 1,000 entities.
        try await photoStore.addTag(tag, toPhotosWith: photos.identifiers)
        return .result()
    }
}
```

- `photos.identifiers` is the array of ids. When you genuinely need the full entities, call `await photos.resolvedEntities()` (it resolves via your query and caches the result).
- `EntityCollection` conforms to `Collection` / `Sequence` / `ExpressibleByArrayLiteral`, with `count`, `isEmpty`, `contains`, `append`, `remove`, and `init(entities:)` / `init(identifiers:)`.

The change from `[PhotoEntity]` to `EntityCollection<PhotoEntity>` is tiny; the speedup on large selections is large. Reach for it whenever a parameter can hold many entities and your `perform()` mostly needs ids. For a handful of entities where you use their properties, a plain `[Entity]` array is fine.

## Keep perform() typed

Always type the perform result to match exactly what you return - `some IntentResult & ProvidesDialog & ReturnsValue<Int>` must match the `.result(...)` call or the runtime will crash. When in doubt, return less (`some IntentResult`) and add capabilities as you wire them up.
