# Testing App Intents

There are two complementary layers:

1. **Direct struct unit tests** - App Intents are plain Swift structs; instantiate them, set `@Parameter`s, call `perform()`, assert. Fast, host-testable (macOS), great for the *logic inside* `perform()` and for queries in isolation. Covered first below.
2. **`AppIntentsTesting`** (iOS 27+, new framework) - runs your real intents **out-of-process on a device/simulator** through the full App Intents stack, the same code path Siri and Shortcuts hit. This is how you cover entity queries, Spotlight indexing, view annotations, and multi-intent composition end-to-end, in CI, without Siri. Covered in its own section below.

Use both: struct tests for pure logic you can run anywhere; `AppIntentsTesting` for the integration surface that only behaves correctly on-device.

## Unit-testing an intent

Instantiate the intent, assign `@Parameter` values, call `perform()`:

```swift
import Testing
import AppIntents
@testable import MyApp

@Suite
struct RefreshFeedIntentTests {
    @Test
    func refreshReturnsCount() async throws {
        var intent = RefreshFeedIntent()
        intent.folder = FolderEntity(id: UUID(), name: "Morning Reads")

        let result = try await intent.perform()

        #expect(result.value == 42)   // the chained-returns-value
    }
}
```

Key points:

- `@Parameter`-wrapped properties are writable from outside the struct in test code. Assign directly (`intent.folder = ...`).
- `perform()` is `async throws`. Use `#expect(throws:)` for error paths.
- Don't run full intent validation (Siri phrase matching, metadata extraction) in unit tests. That's the system's job; your test covers the *behavior* inside `perform()`.

## Mocking dependencies

`AppDependencyManager` is the same registry used by production code. Register test doubles at the top of the test suite:

```swift
protocol FeedStoreType: Sendable {
    func refresh() async throws -> Int
}

final class MockFeedStore: FeedStoreType {
    var refreshCallCount = 0
    func refresh() async throws -> Int {
        refreshCallCount += 1
        return 7
    }
}

@Suite
struct RefreshFeedIntentTests {
    init() {
        AppDependencyManager.shared.add { MockFeedStore() as FeedStoreType }
    }

    @Test
    func callsStoreExactlyOnce() async throws {
        let intent = RefreshFeedIntent()
        _ = try await intent.perform()

        // Read the mock back by resolving the dependency the same way the intent did
        let store = AppDependencyManager.shared.resolve(FeedStoreType.self) as! MockFeedStore
        #expect(store.refreshCallCount == 1)
    }
}
```

Design dependencies as *protocols*, not concrete classes. The intent declares `@Dependency var store: FeedStoreType`; production registers the real store; tests register a mock. No need to subclass or stub closures.

Reset between tests by re-registering in `init()` - the registry replaces prior bindings:

```swift
@Suite
struct RefreshFeedIntentTests {
    init() {
        AppDependencyManager.shared.add { MockFeedStore() as FeedStoreType }
    }
}
```

## Testing entities and queries

Entity creation:

```swift
@Test
func entityMapsFromModel() {
    let article = Article(id: UUID(), title: "Hello", summary: "World")
    let entity = ArticleEntity(article: article)

    #expect(entity.id == article.id)
    #expect(entity.title == "Hello")
}
```

`EntityQuery` lookups:

```swift
@Test
func queryById() async throws {
    AppDependencyManager.shared.add { MockArticleStore() as ArticleStore }

    let query = ArticleEntityQuery()
    let ids = [fixtures.articleA.id, fixtures.articleB.id]
    let results = try await query.entities(for: ids)

    #expect(results.count == 2)
    #expect(Set(results.map(\.id)) == Set(ids))
}

@Test
func queryByString() async throws {
    AppDependencyManager.shared.add { MockArticleStore() as ArticleStore }

    let query = ArticleEntityQuery()
    let results = try await query.entities(matching: "swift")

    #expect(results.contains { $0.title.contains("Swift") })
}
```

`EnumerableEntityQuery`:

```swift
@Test
func allFoldersReturnsFullList() async throws {
    let query = FolderEntityQuery()
    let all = try await query.allEntities()
    #expect(all.count == 5)
}
```

`EntityPropertyQuery` (predicate + sort):

```swift
@Test
func articlesSortedByDate() async throws {
    let query = ArticleEntityQuery()
    let predicates: [Predicate<ArticleEntity>] = [
        #Predicate { $0.title.contains("iOS") }
    ]
    let sorted = try await query.entities(
        matching: predicates,
        mode: .and,
        sortedBy: [EntityQuerySort(by: \.$publishedAt, order: .descending)],
        limit: 10
    )

    #expect(sorted.first?.publishedAt ?? .distantPast >= sorted.last?.publishedAt ?? .distantFuture)
}
```

## Testing error paths

`throws` paths use `#expect(throws:)`:

```swift
@Test
func missingFolderThrows() async throws {
    AppDependencyManager.shared.add { EmptyStore() as ArticleStore }

    var intent = OpenArticleIntent()
    intent.target = ArticleEntity(id: UUID(), title: "")   // id that won't resolve

    await #expect(throws: ArticleIntentError.notFound) {
        _ = try await intent.perform()
    }
}
```

Prefer specific error types over `Error.self` - the assertion actually verifies the intent threw the right error, not just *any* error.

## Testing the `AppShortcutsProvider`

You can't test phrase matching (that's the system), but you can verify the provider's shape:

```swift
@Test
func providerExposesExpectedIntents() {
    let shortcuts = ReaderShortcuts.appShortcuts
    let titles = shortcuts.map { $0.shortTitle }

    #expect(titles.contains("Refresh Feed"))
    #expect(titles.contains("Open Article"))
    #expect(shortcuts.count <= 10)   // hard limit
}
```

Use this as a guard against someone accidentally removing a shortcut during a refactor.

## Testing snippet intents

`SnippetIntent.perform()` is supposed to be pure - perfect for unit tests. Call it, inspect the returned view via `result.view`:

```swift
@Test
func snippetRendersCurrentCount() async throws {
    AppDependencyManager.shared.add {
        MockDashboardStore(unreadCount: 42) as DashboardStore
    }

    let intent = DashboardSnippetIntent()
    let result = try await intent.perform()

    // The returned view is a SwiftUI View; verify it was constructed without error.
    // Assert on the data that drove the view, not on SwiftUI internals.
    let store = AppDependencyManager.shared.resolve(DashboardStore.self) as! MockDashboardStore
    #expect(store.unreadCount == 42)
}
```

Do **not** try to assert on SwiftUI view hierarchies - use the dependency's observed state as the proxy.

## `AppIntentsTesting`: the official integration framework (iOS 27+)

`AppIntentsTesting` runs your real intents **out-of-process**, on a device or simulator, through the full App Intents stack - no mocks, no stubs, the same path Siri and Shortcuts use. It's the way to regression-test the integration surface (queries, Spotlight, view annotations) that struct unit tests can't reach.

How it's wired:

- Tests live in a **UI Testing bundle (XCUITest)** - create one (or add to your existing UI tests). They run in their own process; your app runs in a separate process and executes the intents on-device. The runner ferries results across the process boundary.
- The test target **never imports your app code** - you pass a bundle identifier and address everything by string. So your tests don't compile app code in, and they stay stable across releases (no dependency on UI, yours or the system's).
- The runner and the app must use the **same development team** for code signing.
- CI picks it up automatically like any XCUITest.

### First test: run an intent

```swift
import XCTest
import AppIntentsTesting

final class IntentExecutionTests: XCTestCase {
    func testCreateCalendar() async throws {
        let definitions = IntentDefinitions(bundleIdentifier: "com.example.CometCal")

        // Look the intent up by name; make a populated instance.
        let intent = definitions.intents["CreateCalendarIntent"]
            .makeIntent(name: "Occupy Saturn", color: "red")   // AppEnum: pass its raw string value

        // Execute it in the app, across the process boundary.
        let result = try await intent.run()

        // result.value is the perform() return value; dynamic member lookup reads its properties.
        XCTAssertEqual(result.value.title, "Occupy Saturn")
    }
}
```

Notes:

- `makeIntent(...)` populates parameters. Because the test doesn't build against your app, **parameter names/types don't autocomplete** - fill them in correctly by hand against the intent's declaration. Most types convert from their Swift value; an `AppEnum` is passed as its **raw string value**; for custom parameter types see `IntentValueConvertibleWrapper`.
- `.run()` returns a `ResolvedIntentResult`; `result.value` plus dynamic member lookup (`result.value.title`) reads the returned entity's properties.

### Test entity queries (string, identifier, suggested)

```swift
let events = definitions.entities["EventEntity"]
let matches = try await events.entities(matching: "Cosmic Ray")   // runs the EntityStringQuery on-device
XCTAssertEqual(matches.count, 1)
XCTAssertEqual(matches.first?.title, "Cosmic Ray Calibration")    // dynamic member lookup
```

`AppEntityDefinition` exposes `entities(matching:)`, `entities(identifiers:)`, `allEntities()`, `suggestedEntities()`, and `makeReference(identifier:)`. This is exactly the surface Shortcuts/Siri hit when resolving a parameter - a great target for test-driven query development (write the failing `entities(matching:)` test, then implement `EntityStringQuery`).

### Compose intents (chaining, like Shortcuts)

Pass an entity returned from one run straight into the next - mirroring how people build shortcuts:

```swift
let created = try await definitions.intents["CreateEventIntent"]
    .makeIntent(title: "Asteroid Dodgeball", startDate: date, calendar: "Deep Space")  // string auto-resolves to CalendarEntity
    .run()

let updated = try await definitions.intents["UpdateEventIntent"]
    .makeIntent(event: created.value, title: "Asteroid Dodgeball - Rules")             // pass the returned entity directly
    .run()

XCTAssertEqual(updated.value.title, "Asteroid Dodgeball - Rules")
```

When a parameter expects an entity (`CalendarEntity`) you can pass a plain string; the runtime calls that entity's `EntityStringQuery` and fills in the first match.

### Test Spotlight indexing

`spotlightQuery(_:)` queries the real Spotlight index, so you can guard against the classic "I commented out the indexing call and never noticed" regression:

```swift
let events = definitions.entities["EventEntity"]
XCTAssertTrue(try await events.spotlightQuery("Dark Matter Symposium").isEmpty)   // not created yet

_ = try await definitions.intents["CreateEventIntent"].makeIntent(title: "Dark Matter Symposium", /* ... */).run()

let indexed = try await events.spotlightQuery("Dark Matter Symposium")
XCTAssertEqual(indexed.count, 1)
XCTAssertEqual(indexed.first?.title, "Dark Matter Symposium")
```

### Test view annotations (onscreen awareness)

`viewAnnotations()` returns the entities the system currently reports as on screen - so you can prove "Siri knows which event is on screen" after navigation:

```swift
_ = try await definitions.intents["OpenEventIntent"].makeIntent(target: someEventReference).run()
// (Because this is an XCUITest bundle, you can also drive/assert UI with XCUIApplication here.)

let annotations = try await definitions.entities["EventEntity"].viewAnnotations()
XCTAssertEqual(annotations.count, 1)
XCTAssertEqual(annotations.first?.entity.title, "Meteor Shower Watch Party")
```

A `ViewAnnotation` has `.entity` (with dynamic member lookup) and `.isSelected`. This is how you'd catch a bug like passing the wrong `EntityIdentifier` (e.g. the calendar id instead of the event id) into a `.appEntityIdentifier` modifier.

### Test-only intents

Because these tests run the real stack, each test must be **self-contained**. Test-only intents make that practical: small intents that exist purely to support tests.

- **Seed/reset data** - e.g. a `SeedSampleEventsIntent` that wipes app data and inserts a known set, run from `setUp()`. No leftovers, no flakiness.
- **Jump to any view** without UI navigation - survives screen redesigns.
- **Wrap functionality you haven't exposed as an intent yet** - internal navigation, data management, state manipulation - so it's reachable from `AppIntentsTesting`.

Make any intent test-only by marking it `isDiscoverable: false` (so the system never surfaces it) and wrapping it in `#if DEBUG` (so it ships in no release build):

```swift
#if DEBUG
struct SeedSampleEventsIntent: AppIntent {
    static let title: LocalizedStringResource = "Seed Sample Events"
    static let isDiscoverable: Bool = false

    @Dependency var store: CalendarManager

    @MainActor
    func perform() async throws -> some IntentResult {
        try store.resetAndSeedSampleEvents()
        return .result()
    }
}
#endif
```

### Where it fits

The recommended progression: build the fundamental types → cover them with `AppIntentsTesting` as **unit tests** → integrate deeper (annotate views, donate to Spotlight, transfer content) → cover those as **integration tests** → finally exercise the real thing manually in Shortcuts and Siri. The framework tests intents, entities, enums, queries, and system integrations all out-of-process and automated; manual Siri/Shortcuts testing is still the last step for the natural-language experience.

## What you can't unit-test

These require a device (or a specific test harness) and aren't amenable to direct `@Test` struct calls. Several are now reachable with `AppIntentsTesting` (above) instead:

- **Siri phrase recognition.** Speech recognition is integrated with the OS. Use Xcode's App Shortcuts Preview tool (macOS Sonoma + Xcode 15+) to exercise phrase matching without voice; for voice, test on a real device.
- **Spotlight indexing.** Whether an entity *is* indexed is now testable with `AppIntentsTesting`'s `spotlightQuery(_:)` (on-device). *Ranking* within the semantic index is still opaque - there's no programmatic ranking API.
- **View annotations / onscreen awareness.** Now testable with `AppIntentsTesting`'s `viewAnnotations()` - assert which entity the system reports on screen. (Phrase resolution against those annotations still needs Siri.)
- **Snippet rendering as a system overlay.** Tests can verify the view is constructed; only the snippet host shows the overlay visually.
- **Apple Intelligence invocations.** Most assistant-schema surfaces roll out gradually. Test the intent itself with `AppIntentsTesting`, or via the Shortcuts app (filter by "AssistantSchemas"), until Siri consumer surfaces ship.
- **Visual Intelligence pixel-buffer matching.** Requires the camera / screenshot context. Stub `IntentValueQuery.values(for:)` at the boundary and unit-test the stubbed function; integration-test on device.
- **Widget + control redraw cycles.** Test the intent's mutation; the widget's visual refresh needs a device or the widget simulator.

## Integration-testing through Shortcuts

The Shortcuts app itself is the best zero-code integration harness:

1. Build + run on a device or simulator.
2. Open Shortcuts → tap `+` → search for your intent.
3. Configure parameters, run.
4. Verify dialog, return value, snippet.

For assistant-schema intents, filter Shortcuts' library by "AssistantSchemas" to see only the schema-conforming subset.

For visual intelligence, invoke the system's Visual Intelligence flow on a real device and confirm your `IntentValueQuery` returns results.

## Fixtures and test data

Keep a `Fixtures` namespace with canned entities:

```swift
enum Fixtures {
    static let articleA = ArticleEntity(
        id: UUID(),
        title: "Dive into App Intents",
        summary: "..."
    )
    static let articleB = ArticleEntity(
        id: UUID(),
        title: "Getting Started with SwiftData",
        summary: "..."
    )
}
```

Using fresh UUIDs per test run is fine for in-memory mocks. Use stable UUIDs (hard-coded in source) when a test depends on ordering or when multiple tests share a mock store.

## Running tests

Tests run on the host platform (macOS) unless you specifically need device-side APIs. App Intents' core protocols, macros, and property wrappers work under macOS test builds, so most of the unit-test surface is host-testable.

For device-only features (Spotlight APIs, `UIApplication`-dependent flows), gate tests with `@available(iOS ..., *)` and use a physical device in CI.
