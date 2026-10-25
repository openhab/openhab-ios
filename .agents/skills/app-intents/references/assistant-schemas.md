# Assistant schemas (Apple Intelligence)

Regular `AppEntity` / `AppIntent` let Siri understand *your* concepts. **Assistant schemas** let Siri understand your concepts *in terms of shared cross-app categories* - journal entries, mail messages, browser bookmarks, photo assets, spreadsheet cells. This is the layer that lets Apple Intelligence compose across apps ("take the last three photos I shared in Messages and draft a journal entry about them").

Requires iOS 18.2+ for most schemas; some journaling, mail, and spreadsheet schemas require 18.4+. Availability of the *features that consume* these schemas is rolling out slowly - adopting the schema makes your data eligible, it does not guarantee it will be used.

## App Intent Domains

Schemas are grouped into **domains** - one per app category Apple has pre-trained Siri/Apple Intelligence on. Each domain ships with `create`, `open`, `update`, `delete`, and `search` schema variants, with ~100 pre-trained intents across the lineup.

Domains shipped so far:

- `.books` - read position, annotations, library
- `.browser` - tabs, bookmarks, history
- `.calendar` - events, calendars, attendees (`.calendar.event`, `.calendar.calendar`, `.calendar.attendee`, `createEvent`, `updateEvent`, `deleteEvent`, ...)
- `.camera` - capture flows
- `.files` - document operations
- `.journal` - entry composition and search
- `.mail` - compose, reply, search (`sendMessage` pairs with `draftMessage` - see "A schema can require its siblings" below)
- `.messages` - send / draft messages
- `.photos` - assets, albums, persons
- `.presentations` - slides, decks
- `.spreadsheets` - cells, ranges, templates
- `.system` - search (`.system.searchInApp`), share, print, `.system.open`
- `.systemSearch` - search queries and suggestions
- `.visualIntelligence` - semantic content search
- (Others roll out in later iOS releases.)

The autocomplete-driven snippets (below) are the authoritative list - Apple adds domains and schemas in minor OS releases. In the code-along workflow, you type the domain prefix (`calendar_`, `photos_`, ...) and Xcode offers every schema in that domain.

Adopt the most specific domain that matches your app. A reading app uses `.books`; a markdown-notes app uses `.journal`; a scanner app uses `.files` + `.photos`.

## Adopting a schema

Use `@AssistantEntity(schema:)` on an entity type:

```swift
import AppIntents
import CoreLocation

@AssistantEntity(schema: .journal.entry)
struct JournalEntryEntity: IndexedEntity {
    var id: UUID

    // These names and types are prescribed by the schema - you cannot rename them
    var title: String?
    var message: AttributedString?
    var mediaItems: [IntentFile]
    var entryDate: Date?
    var location: CLPlacemark?

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Journal entry"
    static let defaultQuery = JournalEntryEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title ?? "Untitled")")
    }
}
```

Key consequences:

- **Prescribed property names and types.** `message` must be `AttributedString?`, not `String`. `entryDate` is `Date?`, optional. `location` is `CLPlacemark?`. The macro validates these and emits opaque compiler errors if you deviate.
- **More optionality than you'd expect.** Many schema-required fields are optional even when your real data always has them. Provide sensible fallbacks in initializers or display representations.
- **Import `CoreLocation`** for any schema that carries location.

### A convenience initializer

Because the macro rewrites stored properties to private `_entityProperty`-wrapped versions, the synthesized init is ugly. Provide your own `init` for internal use:

```swift
init(id: UUID, title: String?, body: String, createdAt: Date?, location: CLPlacemark? = nil) {
    self.id = id
    self.title = title
    self.message = AttributedString(body)
    self.mediaItems = []
    self.entryDate = createdAt
    self.location = location
}
```

## Adopting intent schemas

Symmetric to entities. Use `@AssistantIntent(schema:)` or the newer `@AppIntent(schema:)` form:

```swift
@AppIntent(schema: .photos.createAssets)
struct CreateAssetsIntent: AppIntent {
    var files: [IntentFile]

    @Dependency
    var library: MediaLibrary

    @MainActor
    func perform() async throws -> some ReturnsValue<[AssetEntity]> {
        guard !files.isEmpty else { throw IntentError.noEntity }

        var result: [AssetEntity] = []
        for file in files {
            let asset = try await library.createAsset(from: file)
            result.append(asset.entity)
        }
        return .result(value: result)
    }
}

@AppIntent(schema: .photos.openAsset)
struct OpenAssetIntent: OpenIntent {
    var target: AssetEntity
    @Dependency var library: MediaLibrary
    @Dependency var navigation: NavigationManager

    @MainActor
    func perform() async throws -> some IntentResult {
        let assets = library.assets(for: [target.id])
        guard let asset = assets.first else { throw IntentError.noEntity }
        navigation.openAsset(asset)
        return .result()
    }
}

@AppIntent(schema: .photos.updateAsset)
struct UpdateAssetIntent: AppIntent {
    var target: [AssetEntity]
    var name: String?
    var isHidden: Bool?
    var isFavorite: Bool?

    @Dependency var library: MediaLibrary

    func perform() async throws -> some IntentResult {
        let assets = await library.assets(for: target.map(\.id))
        for asset in assets {
            if let isHidden   { try await asset.setIsHidden(isHidden) }
            if let isFavorite { try await asset.setIsFavorite(isFavorite) }
        }
        return .result()
    }
}

@AppIntent(schema: .photos.deleteAssets)
struct DeleteAssetsIntent: DeleteIntent {
    static let openAppWhenRun = true

    var entities: [AssetEntity]

    @Dependency var library: MediaLibrary

    @MainActor
    func perform() async throws -> some IntentResult {
        let ids = entities.map(\.id)
        let assets = library.assets(for: ids)
        try await library.deleteAssets(assets)
        return .result()
    }
}

@AppIntent(schema: .photos.search)
struct SearchAssetsIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.general]

    var criteria: StringSearchCriteria

    @Dependency var navigation: NavigationManager

    @MainActor
    func perform() async throws -> some IntentResult {
        navigation.openSearch(with: criteria.term)
        return .result()
    }
}
```

The schema dictates:

- Which parameters are required/optional and what their names must be.
- What the intent must return (often an entity of the matching schema type).
- Which intent subprotocol to conform to (`OpenIntent` for `.photos.openAsset`, `DeleteIntent` for `.photos.deleteAssets`, `ShowInAppSearchResultsIntent` for `.photos.search`, ...).

`@AppIntent(schema:)` is the modern syntax; `@AssistantIntent(schema:)` works too and is equivalent. New code should use `@AppIntent(schema:)`.

## A schema can require its siblings (Xcode enforces it)

Some Siri flows are incomplete with a single schema. If you adopt `.messages.sendMessage` but **not** `.messages.draftMessage`, the project **fails to build** with a diagnostic - sending a message via Siri also needs a draft step (for confirmation before sending). This is a deliberate design hint surfaced at compile time rather than failing silently at runtime.

Click the error and Xcode offers a **fix-it** that generates a correctly-wired stub adoption of the missing schema - the intent definition, the required parameters, and a `perform()` stub. You then fill in the app-specific pieces: connect entities, inject dependencies (`@Dependency`), process the input, open the right view. If the action mutates UI state, mark its `perform()` `@MainActor`.

Treat these errors as a checklist toward a complete, high-quality integration. The build system tells you what's missing and helps you scaffold it.

## Testing schema intents before Apple Intelligence reaches users

Assistant-schema intents light up in Siri / Apple Intelligence gradually as Apple rolls each schema's consumer out. Before that happens, test them **inside the Shortcuts app**:

- In Shortcuts' library, filter by **AssistantSchemas** to see only schema-conforming intents.
- Configure and run them manually like any other action; the execution path is the same as when Siri invokes them.
- Once the consuming Apple Intelligence surface ships, no code changes are needed - the same intents automatically become Siri-addressable.

This is the intended validation path while schemas are still rolling out.

## Xcode schema code snippets

Xcode 16+ ships code snippets for every schema. Type the domain name (`journal`, `photos`, `mail`) in the editor; completion offers pre-filled skeletons for each schema's intent, entity, and enum - the names and types are already correct, so you avoid the macro's cryptic "field doesn't match schema" errors.

Use the snippets for first-time adoption. Hand-writing a schema type from the API docs alone is error-prone because the macro rejects small deviations without helpful diagnostics.

### Browsing available schemas

Type a domain name followed by a dot in the macro argument, and Xcode completion lists every schema in that domain:

```swift
@AppIntent(schema: .photos.|)     // Xcode shows .asset, .album, .createAssets, .openAsset, ...
@AppEntity(schema: .journal.|)    // Xcode shows .entry, .entryLocation, ...
```

Faster than grepping Apple's documentation. Use completion as the authoritative list; Apple adds schemas in minor OS releases without always updating the doc-set indexing.

## Schema-adopted enums

Enums can also declare schema adoption. The macro enforces allowed case names:

```swift
@AppEnum(schema: .photos.assetType)
enum AssetType: String, AppEnum {
    case photo
    case video

    static let caseDisplayRepresentations: [AssetType: DisplayRepresentation] = [
        .photo: "Photo",
        .video: "Video"
    ]
}
```

The `.photos.assetType` schema requires exactly `.photo` and `.video` cases. Adding a `.livePhoto` case without schema support won't compile; you'd need a separate non-schema enum.

## Schema-adopted entities

Using the entity macro in combination with a photo schema:

```swift
@AppEntity(schema: .photos.asset)
struct AssetEntity: IndexedEntity {

    static let defaultQuery = AssetQuery()

    let id: String
    let asset: Asset

    @Property(title: "Title")
    var title: String?

    var creationDate: Date?
    var location: CLPlacemark?
    var assetType: AssetType?
    var isFavorite: Bool
    var isHidden: Bool
    var hasSuggestedEdits: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: title.map { "\($0)" } ?? "Unknown",
            subtitle: assetType?.localizedStringResource ?? "Photo"
        )
    }
}
```

The schema enforces field names (`creationDate`, `location`, `isFavorite`, etc.) and their types. The macro emits compilation errors if you rename or retype.

## Schema-specific intent protocols

Several intent subprotocols target a specific schema behavior:

### `DeleteIntent`

```swift
@AppIntent(schema: .photos.deleteAssets)
struct DeleteAssetsIntent: DeleteIntent {
    static let openAppWhenRun = true
    var entities: [AssetEntity]
    ...
}
```

Exposes the intent as a system-standard delete action. The system may prompt for confirmation automatically before invoking `perform()`.

### `ShowInAppSearchResultsIntent`

```swift
@AppIntent(schema: .photos.search)
struct SearchAssetsIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.general]
    var criteria: StringSearchCriteria
    ...
}
```

Routes a system search query into the app's in-app search UI. Siri / Spotlight / visual intelligence can invoke this so results surface inside the app's native search rather than as external cards.

`.system.searchInApp` is the generic version of this schema, usable by any app type. It is the **new name** (the 27 releases) for the `.system.search` schema introduced in iOS 17 - update references if you adopted the old name. Photo and mail apps use the domain-specific variants (`.photos.search`, `.mail.search`). It works regardless of which other domains you adopt, even if you index nothing.

### `OpenIntent` with `.system.open` (the 27 releases)

`.system.open` is the generic "open this thing" schema. Any app can adopt it on its `OpenIntent`, and it's the intent that lets Siri resolve "open *X* in MyApp" against your indexed entities. A schema intent gets its title and parameter shape from the schema, so declare `target` as a plain property - no `@Parameter`, no `title`:

```swift
@available(iOS 27, *)
@AppIntent(schema: .system.open)
struct OpenRouteIntent: OpenIntent, TargetContentProvidingIntent {
    var target: RouteEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentRouter.dispatch(.openRoute(id: target.id))
        return .result()
    }
}
```

If you deploy below iOS 27, keep a regular intent for older systems. It can't be the same type (the macro and schema are iOS 27-only), so it's a sibling that funnels into the same action:

```swift
struct ShowRouteIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Route"
    static let openAppWhenRun = true

    @Parameter(title: "Route")
    var route: RouteEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentRouter.dispatch(.openRoute(id: route.id))
        return .result()
    }
}
```

Two follow-ons people miss:

- **Donate the intent that matches the running OS.** Donating the legacy intent on iOS 27 teaches the system the wrong action; donating the schema intent on iOS 18 doesn't compile without a guard:

  ```swift
  func didOpenRouteFromUI(_ entity: RouteEntity) {
      if #available(iOS 27, *) {
          var intent = OpenRouteIntent()
          intent.target = entity
          IntentDonationManager.shared.donate(intent: intent)
      } else {
          var intent = ShowRouteIntent()
          intent.route = entity
          IntentDonationManager.shared.donate(intent: intent)
      }
  }
  ```

- **Point App Shortcut phrases at the intent that exists on every supported OS** - the legacy one (`"Show \(\.$route) in \(.applicationName)"`). An `AppShortcut` built on the iOS 27-only intent would need availability gating inside `appShortcuts`, and the parameterized phrase still needs `updateAppShortcutParameters()` whenever the entity list changes.

When two entities both partially match the spoken name ("Park North" and "Park South" for "open Park"), Siri asks "Which one?" on its own - no disambiguation code needed. Give entities distinctive `DisplayRepresentation` titles so that prompt stays short.

## Apple Intelligence through Shortcuts: the Use Model action

iOS 26+. Shortcuts ships a **Use Model** action that invokes on-device, Private Cloud Compute, or ChatGPT models, with App Entities as input and output:

- **App entity input** - the Shortcuts runtime serializes the entity to JSON (its display representation, type name, and exposed `@Property` values) and passes that to the model as context.
- **Output** - the model can emit text, dictionaries, booleans, or an App Entity of a type you declare. Downstream intents receive it as a typed value.
- **Follow-up turns** - the action supports multi-turn conversation, useful for assistants-over-app-data flows.

For intent authors, two implications:

### Accept `AttributedString`, not `String`, for text parameters

When an intent's text parameter may receive model output, declare it as `AttributedString`:

```swift
@Parameter(title: "Body")
var body: AttributedString
```

Models increasingly generate rich text (bold, italic, lists, tables). `String` parameters lose formatting; `AttributedString` preserves it losslessly. Internally, drop to `String(body.characters[...])` when you need plain text.

### Expose the fields the model should see via `@Property`

The JSON the Use Model action sends to the model is built from your entity's `@Property`-exposed fields (plus `typeDisplayRepresentation` and `displayRepresentation`). Fields not marked `@Property` are invisible to the model. Audit your entities for anything a user-friendly model response would need.

This is a direct, low-ceremony integration point with Apple Intelligence that requires no schema adoption - any `AppIntent` with well-shaped entities participates automatically.

## Visual intelligence: `IntentValueQuery` + `@UnionValue`

On iOS 18.4+, the system's **visual intelligence** feature lets a user circle an object (in the camera view or on screen) to search across apps. An app participates by implementing an `IntentValueQuery` that takes a `SemanticContentDescriptor` (carrying a pixel buffer) and returns matching entities.

Declare the set of result kinds with `@UnionValue`:

```swift
#if canImport(VisualIntelligence)
import AppIntents
import VideoToolbox
import VisualIntelligence

@UnionValue
enum VisualSearchResult {
    case landmark(LandmarkEntity)
    case collection(CollectionEntity)
}

struct LandmarkIntentValueQuery: IntentValueQuery {

    @Dependency var modelData: ModelData

    func values(for input: SemanticContentDescriptor) async throws -> [VisualSearchResult] {

        guard let pixelBuffer: CVReadOnlyPixelBuffer = input.pixelBuffer else {
            return []
        }

        let landmarks = try await modelData.search(matching: pixelBuffer)
        return landmarks
    }
}
#endif
```

`@UnionValue` lets one query return multiple entity types; the system displays them as a unified result list. Use one case per entity type.

To route the user back into the app after they pick a result, pair the query with a schema-adopted intent:

```swift
#if canImport(VisualIntelligence)
@AppIntent(schema: .visualIntelligence.semanticContentSearch)
struct ShowSearchResultsIntent {
    static let title: LocalizedStringResource = "Image Search"
    var semanticContent: SemanticContentDescriptor
}

extension ShowSearchResultsIntent: TargetContentProvidingIntent {}
#endif
```

Guard the visual-intelligence surface with `#if canImport(VisualIntelligence)` if you support OS versions before the feature existed.

### Now on iPad and macOS

As of the 27 releases, Visual Intelligence runs on **iOS, iPadOS, and macOS** - the same `IntentValueQuery`, entities, and `OpenIntent` work across all three with no code changes. Platform differences to handle:

- **Entry point.** iOS is camera-first (physical objects - vinyl, posters); macOS and iPad are screenshot-first (digital media). Make sure your search handles both kinds of input well.
- **Image size.** On Mac the input pixel buffer can be much larger than on iPhone; consider resizing before feeding it to your matcher.

### Result display and continuation

- The `DisplayRepresentation` is the first thing shown - roughly **three lines of text** (title + subtitle) plus a thumbnail. Put the most identifying info first. Serve a **thumbnail-sized** image, not your full-resolution asset (faster load, fine in the two-column layout). If you return a single result, that image takes the full width of the sheet.
- Return results **fast and ranked**; limit the count to keep them relevant; return an empty array when there's no good match (the system shows an empty state).
- The `OpenIntent` runs as the app foregrounds - keep it lightweight; do navigation, defer heavy loading until after the view appears. Reuse an existing `OpenIntent`; you don't need a Visual-Intelligence-specific one.
- Offer a way into your **full** in-app search with the `.visualIntelligence.semanticContentSearch` schema (the "More results" button). The system provides the `SemanticContentDescriptor`; pre-populate your search view from it rather than starting blank.

### Receiving data from Visual Intelligence: system stores

There's a second direction. Beyond *providing* results through image search, your app can *receive* data Visual Intelligence writes into shared **system stores** - automatically, if you already read from them:

- **Events** via EventKit (`EKEventStore`) - e.g. a concert captured from a poster appears in your calendar reads.
- **Contacts** via Contacts (`CNContactStore`) - e.g. a contact captured from a business card.
- **Medical-device readings** via HealthKit (`HKHealthStore`) - e.g. blood-pressure/glucose/scale readings captured from a display.

Add a notification observer (e.g. `EKEventStoreChanged`) so newly-captured items - including ones created by Visual Intelligence - surface in your app without manual entry. No App Intents code is required for this side; it's a benefit you get for free if your app already reads those stores.

## Making onscreen content available to Siri

The on-screen awareness story (which view annotation API to use, content transfer with `Transferable` / `IntentValueRepresentation`, entity annotations on notifications / Now Playing / AlarmKit) now has its own reference: **`onscreen-awareness.md`**. The legacy `userActivity(_:element:)` pattern below remains the right choice for a single primary onscreen item and for older OS versions.

## Making onscreen content available to Siri: `userActivity(_:element:)`

When an entity is visible in your UI, Siri / Apple Intelligence can refer to it ("what can I do with this photo?") if the app declares an `NSUserActivity` that links the visible view to the entity.

```swift
import SwiftUI

struct AssetDetailView: View {
    let asset: Asset

    var body: some View {
        MediaView(image: asset.image)
            .userActivity(
                "com.example.MyApp.ViewingPhoto",
                element: asset.entity
            ) { element, activity in
                activity.title = "Viewing a photo"
                activity.appEntityIdentifier = EntityIdentifier(for: element)
            }
    }
}
```

Two required parts:

- `element:` - the `AppEntity` instance the view represents.
- `activity.appEntityIdentifier = EntityIdentifier(for: element)` - this is what lets the system correlate "the thing on screen" with a specific entity your app understands.

For Siri to actually forward the entity's *content* (not just reference it), the entity must also conform to `Transferable` (see `entities.md`). Text, image, and PDF representations are the most commonly useful.

A typical setup:

1. Declare the entity with `@AppEntity(schema:)` or plain `AppEntity`.
2. Conform it to `Transferable` for exportable content.
3. Register an onscreen activity with `.userActivity(_:element:)` when the view is visible.

With all three in place, Siri can answer "what is this?", forward the content to a third-party service the user taps, or use it as input to another intent - all driven by context rather than explicit commands.

## Available schemas (representative)

Categories (not exhaustive):

- `.books.*` - book, audiobook, library
- `.browser.*` - bookmark, window, tab
- `.files.*` - file
- `.journal.*` - entry, entryLocation, createEntry, updateEntry, searchEntries
- `.mail.*` - message, account, composition
- `.photos.*` - asset, assetType, album, person, createAssets, openAsset, updateAsset, deleteAssets, search
- `.presentations.*` - slide deck, slide
- `.spreadsheets.*` - sheet, cell, range, template
- `.systemSearch.*` - search query, search suggestion
- `.visualIntelligence.*` - semanticContentSearch (for visual intelligence integration)

Xcode 16+ ships code snippets. Type `journal` or `mail` into the editor and the completion menu offers skeletons for each schema's intents and entities; this is by far the fastest way to adopt a schema correctly given how strict the macro is.

## What adoption gets you

In principle:

- Your data participates in system searches ("find the note where I mentioned Berlin").
- Cross-app composition ("take this journal entry and share it in Mail").
- Siri understands domain verbs ("append this to my last journal entry") without you wiring each phrase.

In practice, as of early 2026 the feature surfaces consuming assistant schemas are rolling out unevenly. Adopt where the schema closely matches your domain, but treat actual behavior as a moving target - verify on a current iOS release rather than on the WWDC24 announcement.

## When NOT to adopt

- Your data is genuinely novel and doesn't fit any schema. Don't bend your model to match; stick with plain `AppEntity`.
- The schema forces losing fidelity (e.g., you have rich markdown and the schema insists on `AttributedString` which loses your extensions). Weigh the integration benefit against the modeling cost.
- You're still on iOS 17 or earlier - assistant schemas require 18.2+.

## Versioning caveat

Xcode embeds the schema version ("journal entry 1.0.0") in the macro-expanded code. Schemas are expected to evolve - Apple chose macros precisely so they can add fields without breaking existing adopters. Treat schema adoption as you would any platform API: rev your minimum deployment target when you need newer schema features, and expect some churn at first.

## Co-existence

You can have both a plain `AppEntity` and a schema-adopted entity in the same app. Some flows want the raw type; some want the schema-shaped one. Map between them where needed rather than trying to make one entity wear both hats.
