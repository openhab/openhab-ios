# App entities

`AppEntity` is how the system understands your domain objects. Entities let users pick articles, bookmarks, playlists, rooms, etc., as parameters - by voice, by tapping in Shortcuts, or by selecting in Spotlight.

## The sendability rule

`AppEntity` refines `AppValue` and requires `Sendable`. SwiftData `@Model` classes, Core Data `NSManagedObject`, and any other reference-type data model are **not** sendable. They cannot be `AppEntity`.

```swift
// WRONG - will not compile under Swift 6, produces sendability warnings earlier
@Model
class Article { ... }
extension Article: AppEntity { ... }   // conformance of 'Article' to 'Sendable' unavailable
```

The fix is to create a separate `struct` entity that **shadows** the fields you want to expose to the system, then convert between them at the query boundary.

```swift
struct ArticleEntity: AppEntity {
    var id: UUID
    var title: String
    var summary: String
    var publishedAt: Date
    var thumbnailURL: URL?

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Article"
    static let defaultQuery = ArticleEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(summary)",
            image: .init(systemName: "doc.text")
        )
    }
}
```

In the underlying model, add a computed property to produce the entity cheaply:

```swift
@Model
final class Article {
    var id = UUID()
    var title: String
    var summary: String
    var publishedAt: Date
    var thumbnailURL: URL?

    var entity: ArticleEntity {
        ArticleEntity(
            id: id,
            title: title,
            summary: summary,
            publishedAt: publishedAt,
            thumbnailURL: thumbnailURL
        )
    }

    init(...) { ... }
}
```

Loading entities now means loading models and mapping with `\.entity`:

```swift
try modelContext.fetch(descriptor).map(\.entity)
```

## Required members

An `AppEntity` must provide:

| Member | Purpose |
|---|---|
| `var id: some Hashable & Sendable` | Stable unique identifier. `UUID` works well. |
| `static let typeDisplayRepresentation: TypeDisplayRepresentation` | Type-level name ("Article"). Used in pickers and Siri. |
| `static let defaultQuery: some EntityQuery` | How the system loads entities when it needs to populate parameters. |
| `var displayRepresentation: DisplayRepresentation` | Per-instance label shown in pickers, notifications, Spotlight cards. |

`typeDisplayRepresentation` is shared across all entities of the type; `displayRepresentation` is per-instance. Do not mix them up.

## Entity property wrappers

Fields that the system should expose through Shortcuts pickers, parameter summaries, Find intents, and Spotlight attribute sets need to be wrapped. Plain stored properties are visible to your code but invisible to the App Intents framework.

### `@Property` - exposed stored property

```swift
struct ArticleEntity: AppEntity {
    var id: UUID

    @Property var name: String
    @Property(title: "Region") var regionDescription: String
    @Property var trailLength: Measurement<UnitLength>

    // Not exposed (system cannot query or sort by it)
    var imageName: String
    var currentConditions: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Trail"
    static let defaultQuery = TrailEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(regionDescription)",
                              image: DisplayRepresentation.Image(named: imageName))
    }
}
```

The `@Property` wrapper is what lets you:

- Use the field in a `parameterSummary` key path (`Summary("...\(\.$name)...")`)
- Use it in an `EntityPropertyQuery` (the auto-generated Find intent)
- Reference it in `SortableBy(\.$name)`
- Map it to Spotlight indexing keys via `@ComputedProperty(indexingKey:)`

The title defaults to the variable name; supply `@Property(title: "Region")` to customize.

### `@ComputedProperty` - exposed computed property

Map a computed property onto the exposed surface:

```swift
struct LandmarkEntity: IndexedEntity {
    var landmark: Landmark
    var modelData: ModelData

    @ComputedProperty(indexingKey: \.displayName)
    var name: String { landmark.name }

    // Maps the description variable to the Spotlight indexing key `contentDescription`.
    @ComputedProperty(indexingKey: \.contentDescription)
    var description: String { landmark.description }

    // Maps the continent variable to a custom Spotlight indexing key.
    @ComputedProperty(
        customIndexingKey: CSCustomAttributeKey(
            keyName: "com_example_LandmarkEntity_continent"
        )!
    )
    var continent: String { landmark.continent }
}
```

`indexingKey:` maps the property to one of the standard `CSSearchableItemAttributeSet` keys (`\.displayName`, `\.contentDescription`, `\.keywords`, ...). `customIndexingKey:` uses a custom Spotlight attribute key you declare. Both feed Spotlight automatically - no separate `attributeSet` code needed for those fields.

### `@DeferredProperty` - lazy async property

For fields that are expensive to compute or require async access, don't load them eagerly:

```swift
@DeferredProperty
var crowdStatus: Int {
    get async throws {
        await modelData.getCrowdStatus(self)
    }
}
```

The system only materializes the value when a consumer (a shortcut, Siri, Spotlight) actually needs it. Use `@DeferredProperty` when the value involves a network round-trip, model inference, or an expensive database aggregation.

### Synonyms invalidate shortcut caches

When the user-visible titles of entities change - through a rename, through adding entries, or through changing `displayRepresentation.synonyms` - call `YourShortcutsProvider.updateAppShortcutParameters()` to let the system refresh the suggestion cache. See `shortcuts-and-siri.md`.

## Pluralized type name and synonyms

`TypeDisplayRepresentation` takes an optional `numericFormat` for pluralization, and `DisplayRepresentation` takes `synonyms` so Siri accepts alternate phrasings:

```swift
static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(
        name: LocalizedStringResource("Trail", table: "AppIntents"),
        numericFormat: LocalizedStringResource("\(placeholder: .int) trails", table: "AppIntents")
    )
}

var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
        title: "Workout Summary",
        subtitle: "\(calories) calories",
        image: DisplayRepresentation.Image(systemName: "figure.hiking"),
        synonyms: ["Activity Summary", "Session Summary"]
    )
}
```

## Transient entities

Not all intent-returned data has a persistent identifier. A summary, an aggregated statistic, or a request-scoped wrapper shouldn't conform to `AppEntity` - it would require an `EntityQuery` that makes no sense. Use `TransientAppEntity` instead:

```swift
struct ActivityStatisticsSummary: TransientAppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout Summary")

    @Property var summaryStartDate: Date
    @Property var workoutsCompleted: Int
    @Property var caloriesBurned: Measurement<UnitEnergy>
    @Property var distanceTraveled: Measurement<UnitLength>

    init() {
        summaryStartDate = Date()
        workoutsCompleted = 0
        caloriesBurned = Measurement(value: 0, unit: .calories)
        distanceTraveled = Measurement(value: 0, unit: .meters)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Workout Summary",
                              subtitle: "You burned \(caloriesBurned.formatted()) calories.",
                              synonyms: ["Activity Summary"])
    }
}
```

No `id`, no `defaultQuery` - Shortcuts won't try to enumerate or look them up. But `@Property` still applies, so downstream actions in a shortcut can chain `distanceTraveled` or `caloriesBurned` as typed inputs.

Use `TransientAppEntity` for return data that's computed on the fly and exists only for that intent invocation.

## File-backed entities: `FileEntity`

For entities that *are* files (a scanned document, a recorded voice memo, an image your app produced), `FileEntity` replaces the awkward "entity that exports as a file via Transferable" pattern. iOS 18+.

```swift
import AppIntents
import UniformTypeIdentifiers

struct ScanEntity: FileEntity {
    static let supportedContentTypes: [UTType] = [.pdf, .png]

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Scan"
    static let defaultQuery = ScanEntityQuery()

    var id: FileEntityIdentifier   // built from a URL or a draft identifier
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}
```

`FileEntityIdentifier` wraps either a concrete file URL (with bookmark data for persistence) or a *draft identifier* for files that don't yet exist. The system's file-handling machinery can then act on the entity directly - "rotate this scan", "attach this scan to a message" - without Transferable conversion.

Use `FileEntity` when the thing *is* a file. Use `AppEntity` with `Transferable` when the thing is a domain object that *has* a file representation (among others).

## `@UnionValue` parameters: accept multiple entity types

When a parameter could reasonably be any of several entity types (a route *or* a saved location; an article *or* a bookmark), declare the union as an enum:

```swift
@UnionValue
enum DestinationValue {
    case route(RouteEntity)
    case savedLocation(SavedLocationEntity)
}

struct NavigateIntent: AppIntent {
    @Parameter var destination: DestinationValue

    func perform() async throws -> some IntentResult {
        switch destination {
        case .route(let r):         try await navigator.go(to: r)
        case .savedLocation(let s): try await navigator.go(to: s)
        }
        return .result()
    }
}
```

Each `@UnionValue` case has exactly one associated value, and that value is a distinct type. Shortcuts shows a combined picker; Siri asks a disambiguation question. Preferable to writing two sibling intents that differ only in the parameter type.

Customize how the union appears in the picker with `typeDisplayRepresentation` (the label for the union type) and `caseDisplayRepresentations` (the label per case) - the macro generates the rest (type info, case metadata, picker support):

```swift
@UnionValue
enum PhotoSource {
    case landmarkCollection(LandmarkCollectionEntity)
    case photoAlbum(PhotoAlbumEntity)

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Photo Source")
    static let caseDisplayRepresentations: [PhotoSource: DisplayRepresentation] = [
        .landmarkCollection: "Landmark Collection",
        .photoAlbum: "Photo Album"
    ]
}
```

`@UnionValue` parameters work everywhere your intent does - Shortcuts, Siri, **and widgets** (one widget configuration backing two entity types). The same macro is used for `IntentValueQuery` results (see `assistant-schemas.md` for visual-intelligence examples).

## Transferable entities

Conforming an `AppEntity` to `Transferable` makes it sharable with other apps and forwardable to Siri / Apple Intelligence as concrete data (image, PDF, text, RTF):

```swift
extension LandmarkEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { @MainActor landmark in
            // Render a PDF and return SentTransferredFile(url)
        }

        DataRepresentation(exportedContentType: .image) {
            try $0.imageRepresentationData
        }

        DataRepresentation(exportedContentType: .plainText) {
            """
            Landmark: \($0.name)
            Description: \($0.description)
            """.data(using: .utf8)!
        }
    }
}
```

When Siri or the system share sheet asks for the entity's content, they use this representation. Ordering matters: put richer representations first; the system picks the first one the consumer accepts.

`Transferable` is required for schemas that expect exportable content (e.g., `.photos.asset`). It's also what lets "send this to Mail" or "summarize this" work when the entity is the current onscreen content.

### `ProxyRepresentation` for single-field exports

When the entity's exported content is just one of its own stored properties, skip the `DataRepresentation` closure and use `ProxyRepresentation(exporting:)` with a key path:

```swift
extension JournalEntryEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.entryText)
    }
}
```

Shorter than the closure form; works for any property whose type is itself `Transferable` (`String`, `Data`, `URL`, another entity). The exported content type comes from the property's type.

Use `ProxyRepresentation` for plain passthrough; drop to `DataRepresentation` / `FileRepresentation` closures when the exported bytes are computed from multiple fields or require formatting.

### `IntentValueRepresentation` / `ValueRepresentation` for structured system types (iOS 26.4+)

`FileRepresentation` and `DataRepresentation` only carry known *file formats* (PDF, image, text). A coordinate, a contact, or a person's name has no file format - Maps can't navigate to a `.plainText` blob, it needs a `PlaceDescriptor`. `IntentValueRepresentation` (built with the `ValueRepresentation` builder) bridges your entity to a **system intent value** - `IntentPerson`, `PlaceDescriptor` (GeoToolbox), `PersonNameComponents` - and supports import as well as export. Add it alongside your other representations:

```swift
static var transferRepresentation: some TransferRepresentation {
    // Key-path form when the entity already stores the system type as a @Property:
    ValueRepresentation(exporting: \.place)        // place: PlaceDescriptor

    // Or closure form for export + import:
    ValueRepresentation(
        exporting:  { contact in IntentPerson(name: .displayName(contact.name)) },
        importing:  { person in ContactEntity(name: person.name.displayString) }
    )
}
```

This is what makes "get directions to this landmark" and "call this contact" cross the app boundary. Full treatment - including resolve-existing (`IntentValueQuery`) vs. import-as-new - is in `onscreen-awareness.md`.

## `DisplayRepresentation` anatomy

```swift
var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
        title: "\(title)",
        subtitle: "\(summary)",
        image: .init(systemName: "doc.text")
    )
}
```

### Thumbnail images

iOS 17+ adds an image field that accepts multiple backing sources:

```swift
// Bundled image resource
DisplayRepresentation(title: "\(name)", image: DisplayRepresentation.Image(named: "trail-hero"))

// System image
DisplayRepresentation(title: "\(name)", image: .init(systemName: "doc.text"))

// Remote URL (system fetches and caches)
DisplayRepresentation(title: "\(name)", image: DisplayRepresentation.Image(url: thumbnailURL))

// Raw data (useful when the thumbnail is derived at runtime)
DisplayRepresentation(title: "\(name)", image: .init(data: try entity.thumbnailData))
```

Variants:

```swift
// Minimal
DisplayRepresentation(title: "\(title)")

// Title + subtitle
DisplayRepresentation(title: "\(title)", subtitle: "\(summary)")

// With URL-backed image (thumbnail)
DisplayRepresentation(
    title: "\(title)",
    image: DisplayRepresentation.Image(url: thumbnailURL)
)

// With an SF Symbol
DisplayRepresentation(
    title: "\(title)",
    image: .init(systemName: "book.closed")
)

// With a tinted symbol
DisplayRepresentation(
    title: "\(title)",
    image: .init(systemName: "book.closed", tintColor: .systemBlue)
)
```

## Entity queries

The system cannot guess how to load your entities. You must provide a query.

### `EnumerableEntityQuery` (small, loadable sets)

Use when the whole set is small and cheap to enumerate - folders, tag lists, starter presets.

```swift
struct FolderEntityQuery: EnumerableEntityQuery {
    @Dependency var store: DataStore

    func allEntities() async throws -> [FolderEntity] {
        try await store.folderEntities()
    }

    func entities(for identifiers: [FolderEntity.ID]) async throws -> [FolderEntity] {
        try await store.folderEntities(matching: #Predicate {
            identifiers.contains($0.id)
        })
    }
}
```

`allEntities()` and `entities(for:)` are both required. `entities(for:)` is called when the system already knows the id and needs to resolve it back to an entity - common during Shortcuts re-evaluation.

### `EntityQuery` (large, searchable sets)

Use when there can be thousands of entries. Add `EntityStringQuery` to support search-by-string (Siri spoken lookup, Shortcuts "Find…").

```swift
struct ArticleEntityQuery: EntityQuery {
    @Dependency var store: DataStore

    func entities(for identifiers: [ArticleEntity.ID]) async throws -> [ArticleEntity] {
        try await store.articleEntities(matching: #Predicate {
            identifiers.contains($0.id)
        })
    }

    func suggestedEntities() async throws -> [ArticleEntity] {
        // Shown at the top of pickers; return recent or pinned items.
        try await store.articleEntities(sortBy: [.init(\.publishedAt, order: .reverse)], limit: 10)
    }
}

extension ArticleEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [ArticleEntity] {
        try await store.articleEntities(matching: #Predicate { article in
            article.title.localizedStandardContains(string)
        })
    }
}
```

### `UniqueIDEntityQuery`

Convenience for the common case where you have exactly one identifier column and simple lookup by id.

### `EntityPropertyQuery` - auto-generated Find intent

Conforming your query to `EntityPropertyQuery` automatically adds a **Find intent** to the Shortcuts app - a generic, user-configurable predicate search over the entity's exposed `@Property` fields. Users can build "find articles where title contains X and length less than Y, sorted by date" without you writing that UI.

```swift
extension TrailEntityQuery: EntityPropertyQuery {
    typealias ComparatorMappingType = Predicate<TrailEntity>

    static let properties = QueryProperties {
        Property(\TrailEntity.$name) {
            ContainsComparator { searchValue in
                #Predicate<TrailEntity> { $0.name.localizedStandardContains(searchValue) }
            }
            EqualToComparator { searchValue in
                #Predicate<TrailEntity> { $0.name == searchValue }
            }
            NotEqualToComparator { searchValue in
                #Predicate<TrailEntity> { $0.name != searchValue }
            }
        }

        Property(\TrailEntity.$trailLength) {
            LessThanOrEqualToComparator { searchValue in
                #Predicate<TrailEntity> { $0.trailLength <= searchValue }
            }
            GreaterThanOrEqualToComparator { searchValue in
                #Predicate<TrailEntity> { $0.trailLength >= searchValue }
            }
        }
    }

    static let sortingOptions = SortingOptions {
        SortableBy(\TrailEntity.$name)
        SortableBy(\TrailEntity.$trailLength)
    }

    static var findIntentDescription: IntentDescription? {
        IntentDescription("Search for trails matching complex criteria.",
                          categoryName: "Discover",
                          searchKeywords: ["trail", "location", "travel"],
                          resultValueName: "Trails")
    }

    func entities(matching comparators: [Predicate<TrailEntity>],
                  mode: ComparatorMode,
                  sortedBy: [EntityQuerySort<TrailEntity>],
                  limit: Int?) async throws -> [TrailEntity] {
        // 1. Filter entities against the predicates
        // 2. Sort per `sortedBy`
        // 3. Truncate to `limit`
    }
}
```

Requirements:

- Every property referenced in `QueryProperties` must be marked `@Property` on the entity.
- Each `Property(...)` block lists which comparators users can apply (`ContainsComparator`, `EqualToComparator`, `LessThanOrEqualToComparator`, ...). Only comparators that make semantic sense for the field type are useful.
- `sortingOptions` lists which properties are sortable.
- `findIntentDescription` populates the Shortcuts-app presentation for the auto-generated Find intent.

The `entities(matching:mode:sortedBy:limit:)` function receives closed-over predicates; the `mode` is `.and` or `.or` depending on how the user combined criteria. Loop, evaluate, sort, limit.

### `EnumerableEntityQuery` also supports Find intents

For small fixed sets, `EnumerableEntityQuery` alone gets a basic Find intent (filter-by-name) with no extra code. Add `findIntentDescription` to customize its presentation:

```swift
struct FeaturedCollectionEntityQuery: EnumerableEntityQuery {
    static var findIntentDescription: IntentDescription? {
        IntentDescription("Find a featured collection.",
                          categoryName: "Discover",
                          searchKeywords: ["collection", "featured"],
                          resultValueName: "Collections")
    }

    func allEntities() async throws -> [CollectionEntity] { ... }
    func entities(for identifiers: [CollectionEntity.ID]) async throws -> [CollectionEntity] { ... }
    func suggestedEntities() async throws -> [CollectionEntity] { ... }
}
```

Picking a query conformance:

| Conformance | Find intent? | Best for |
|---|---|---|
| `EntityQuery` | No | Any entity type (baseline) |
| `EntityQuery + EntityStringQuery` | No | Large datasets with search-by-name |
| `EnumerableEntityQuery` | Basic (filter by name) | Small fixed sets (folders, categories) |
| `EntityPropertyQuery` | Full (predicates + sort) | Large datasets with multiple queryable fields |

Apps can adopt multiple conformances on the same query (Apple's `LandmarkEntityQuery` is simultaneously `EntityQuery`, `EntityStringQuery`, and `EnumerableEntityQuery`). Each conformance enables a different system-facing capability.

## Predicate pitfall: local copy of id

When filtering by the entity's id inside `#Predicate`, copy the id to a local constant first. The macro does not reach through property paths on entity types:

```swift
// WRONG - macro cannot reach entity.id in this position
try store.articles(matching: #Predicate { $0.id == entity.id })

// CORRECT
let id = entity.id
try store.articles(matching: #Predicate { $0.id == id })
```

## Registering the default query

Entities reference their query through `defaultQuery`:

```swift
struct ArticleEntity: AppEntity {
    ...
    static let defaultQuery = ArticleEntityQuery()
    ...
}
```

Without `defaultQuery`, parameter pickers are empty and Siri cannot resolve named entities.

## Cross-device identity: `SyncableEntity` (iOS 27+)

Siri can continue a conversation across devices ("add a photo" on iPhone, "tag that photo" on iPad). For that to work, the same entity must have the **same id on every device**. Locally-generated ids (Core Data row ids, per-device UUIDs) break this - each device invents its own.

`SyncableEntity` declares that an entity's id is stable everywhere. If your id is *already* consistent across devices (a server-assigned UUID, a CloudKit record id), just adopt the protocol - no other change:

```swift
struct Article: AppEntity, SyncableEntity {
    var id: UUID          // already stable (from your server) - nothing else to do
    var title: String
    // ...
}
```

If you use a **local** id on-device but have a separate stable id, pair them with `SyncableEntityIdentifier`. Your code keeps using the local id; the system uses the stable one to refer to the entity across devices:

```swift
struct Photo: AppEntity, SyncableEntity {
    var id: SyncableEntityIdentifier<String, String>   // <Local, Stable>
    var creationDate: Date

    init(localID: String, stableID: String, creationDate: Date) {
        self.id = SyncableEntityIdentifier(local: localID, stable: stableID)
        self.creationDate = creationDate
    }
}
```

Adopt `SyncableEntity` on any entity Siri might reference in a conversation that can hop devices.

## Suggesting relevant entities: `RelevantEntities` (iOS 27+)

Spotlight makes content **findable**; interaction donation teaches the system **patterns**. Neither helps with content nobody has searched for or used yet - a brand-new high-tempo playlist that's perfect for a run, but has never been played. `RelevantEntities` lets you *proactively hint* which entities are relevant in a given context, so the system can surface them at the right moment (e.g. as a suggested workout playlist in Fitness).

```swift
// Suggest the running playlists; the system surfaces them in the right context.
let workoutContext = AppEntityContext.audio(.workout(activityType: .running))
try await RelevantEntities.shared.updateEntities(runningPlaylists, for: workoutContext)
```

- Provide the full set at once with `updateEntities(_:for:)` - each call **replaces** your previous suggestions for that context (pass `[]` to clear).
- Entities stay registered until you remove them: `removeEntities(_:from:)`, `removeAllEntities(for:)`, or `removeAllEntities()`. The system also auto-expires suggestions after roughly four weeks if the app isn't launched.
- Build the context from `AppEntityContext` - e.g. `AppEntityContext.audio(.workout(activityType: .running))` for a running workout. Each domain exposes its own nested context cases.

Choosing between the three discovery mechanisms: **Spotlight** when content should be searchable/retrievable by Siri; **interaction donation** to teach the system how people use the app (see `siri-intelligence.md`); **`RelevantEntities`** to hint which content matters in a specific situation.

## Indexed entities (Spotlight)

`IndexedEntity` is a subprotocol of `AppEntity` that makes entities searchable through Spotlight. See `spotlight.md`.

```swift
struct ArticleEntity: IndexedEntity { ... }   // instead of AppEntity
```

No additional required members - the entity's `displayRepresentation` is used to build the Spotlight card automatically. Override `attributeSet` to enrich indexing.
