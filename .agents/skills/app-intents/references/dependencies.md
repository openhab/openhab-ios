# Dependencies and data flow

Intents do not have a SwiftUI `@Environment`. They cannot use `@Query`. They get their collaborators via **`@Dependency`**, which reads from a global registry populated by the app.

## The pattern

1. Build a data controller (or service, navigator, network client) in `App.init()`.
2. Register it with `AppDependencyManager.shared.add(dependency:)`.
3. Declare `@Dependency var x: X` in any intent or entity-query that needs it.

```swift
import AppIntents
import SwiftData
import SwiftUI

@main
struct ReaderApp: App {
    @State private var store: DataStore
    @State private var modelContainer: ModelContainer

    init() {
        let modelContainer: ModelContainer

        do {
            modelContainer = try ModelContainer(for: Article.self)
        } catch {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(for: Article.self, configurations: config)
        }

        self._modelContainer = .init(initialValue: modelContainer)

        let store = DataStore(modelContainer: modelContainer)
        self._store = .init(initialValue: store)

        AppDependencyManager.shared.add(dependency: store)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .modelContainer(modelContainer)
    }
}
```

```swift
struct RefreshFeedIntent: AppIntent {
    @Dependency var store: DataStore

    static let title: LocalizedStringResource = "Refresh feed"

    func perform() async throws -> some IntentResult {
        try await store.refresh()
        return .result()
    }
}
```

`@Dependency` looks up the first registered instance of its type. There's no hierarchy or scoping - it's a flat registry. Register once.

## `App.init()` runs for intents too

When a shortcut fires, the OS launches the app process and runs `App.init()` even if no UI is ever created. That's the window for:

- Creating `ModelContainer`s.
- Registering dependencies.
- Wiring any other setup intents will read.

What does **not** run: `.task`, `.onAppear`, `@StateObject` init closures inside views. If you rely on those for intent-needed setup, the intent will crash or see stale state.

### Process boundaries: app vs extension

When the `AppShortcutsProvider` is in the main app target, the intent runs in the main app process (after `App.init()`). When it's in an App Intents extension (iOS 17+, see "Shared framework extraction" below), the intent runs in a separate, lighter extension process:

- Extension process does **not** share memory with the main app. Singleton state built up in the main app's UI is invisible to the extension.
- Extension process still runs its own `App.init()` or extension-principal initializer, so `@Dependency` wiring works the same way *within* that process.
- Writes to shared storage (App Group `UserDefaults`, App Group file URLs, `ModelContainer` pointed at an App Group URL) are visible to both processes.

Practical implication: treat each intent's collaborators as newly-initialized-per-invocation. Don't cache expensive objects in static vars expecting them to persist across intent runs - the extension is short-lived and may be torn down between invocations. Prefer registering fresh instances through `@Dependency` and letting the platform manage lifetime.

## Data-controller skeleton

A data controller concentrates all SwiftData (or network) access in one place so intents don't re-invent queries:

```swift
import Foundation
import SwiftData

@Observable @MainActor
final class DataStore {
    var modelContext: ModelContext
    var path: [Article] = []
    var searchText = ""

    init(modelContainer: ModelContainer) {
        modelContext = ModelContext(modelContainer)
    }

    func articles(
        matching predicate: Predicate<Article> = #Predicate { _ in true },
        sortBy: [SortDescriptor<Article>] = [SortDescriptor(\.publishedAt, order: .reverse)],
        limit: Int? = nil
    ) throws -> [Article] {
        var descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: sortBy)
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func articleEntities(
        matching predicate: Predicate<Article> = #Predicate { _ in true },
        sortBy: [SortDescriptor<Article>] = [SortDescriptor(\.publishedAt, order: .reverse)],
        limit: Int? = nil
    ) throws -> [ArticleEntity] {
        try articles(matching: predicate, sortBy: sortBy, limit: limit).map(\.entity)
    }

    func articleCount(
        matching predicate: Predicate<Article> = #Predicate { _ in true }
    ) throws -> Int {
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        return try modelContext.fetchCount(descriptor)
    }
}
```

Key conventions:

- **Main-actor bound.** The controller drives UI; pinning it keeps SwiftData access serialized and removes sendability noise.
- **Two return shapes** - one returning `[Article]` (for mutation and UI), one returning `[ArticleEntity]` (sendable; safe to hand across actors to intents).
- **Default-valued parameters** so callers can say `store.articles()` for the common case.

## `ModelContainer` vs `ModelContext` sendability

Only `ModelContainer` is `Sendable`. `ModelContext` is not.

- Pass `ModelContainer` across actors. Create a local `ModelContext(modelContainer)` inside each actor that needs one.
- If you pin the intent's `perform()` (or the data controller) to `@MainActor`, you can use the `modelContainer.mainContext` directly.

```swift
// OK - main-actor perform reads main context
@MainActor
func perform() async throws -> some IntentResult {
    let recent = try store.articles(limit: 5)
    ...
    return .result()
}

// OK - cross-actor access via fresh local context
func perform() async throws -> some IntentResult {
    let container = try ModelContainer(for: Article.self)
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<Article>(predicate: #Predicate { _ in true })
    let count = try context.fetchCount(descriptor)
    ...
    return .result()
}
```

Avoid creating ad-hoc `ModelContainer`s from inside `perform()` when a shared one already exists on your `DataStore`. It works but it wastes the container setup and produces leaky code paths.

## Mutating model objects from an intent

To mutate an `@Model` object from an intent, do it on the main actor, on the same main context:

```swift
struct AppendNoteIntent: AppIntent {
    @Dependency var store: DataStore

    @Parameter(title: "Text")
    var newText: String

    static let title: LocalizedStringResource = "Append to latest note"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let recent = try store.articles(limit: 1)

        guard let first = recent.first else {
            return .result(dialog: "You haven't saved anything yet.")
        }

        first.body.append(" \(newText)")
        try first.modelContext?.save()

        return .result(dialog: "Added.")
    }
}
```

Two things make this work:

1. Both the intent's `perform()` and the data controller are `@MainActor`. No sending of non-sendable data across actors.
2. `first` is the actual `Article` instance, not an `ArticleEntity` copy - so mutations persist.

Calling `try first.modelContext?.save()` explicitly is recommended. SwiftData's autosave is unreliable from intents because the app may be torn down before the next run loop.

## Don't authenticate inside `perform()`

If your app requires login, assume the user is already signed in. If they aren't, return early with a `ProvidesDialog`:

```swift
guard store.isAuthenticated else {
    return .result(dialog: "Sign in to the app first.")
}
```

Don't present an auth sheet from an intent - you'll strand the user in Siri or Shortcuts.

## Shared framework extraction

Larger apps split intents into a separate target. `@Dependency` resolution works across frameworks as long as the dependency is registered in `App.init()`. Three distribution mechanisms, depending on iOS minimum:

### `AppIntentsPackage` protocol (iOS 17+)

Declare the metadata-exporting target with `AppIntentsPackage` so the compiler re-exports its intents recursively into the main app:

```swift
// In the intents framework
import AppIntents

public struct ReaderIntentsPackage: AppIntentsPackage { }
```

```swift
// In the main app
import AppIntents
import ReaderIntents   // the framework

struct ReaderApp: App, AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [ReaderIntentsPackage.self]
    }
    ...
}
```

The main app's package lists the frameworks whose intents should be registered. Supports dynamic frameworks at iOS 17+.

### Swift Packages and static libraries (iOS 26+)

iOS 26 extended `AppIntentsPackage` support to Swift Packages and static library targets. Same protocol, same `includedPackages` declaration. Useful when you want to ship intents from a swift-package dependency without a binary framework target.

### `AppShortcutsProvider` in the App Intents extension (iOS 17+)

Previously, an `AppShortcutsProvider` had to live in the main app bundle, which caused the app to launch every time a shortcut fired. On iOS 17+, the provider can live in an App Intents extension target - shortcuts run in the extension's lighter process, faster and without waking the main app.

## Framework-defined entities

iOS 18+ allows an `AppEntity` defined in a framework to be parameterized by an intent in the main app. Earlier versions required intent and entity in the same module. Registering the framework via `AppIntentsPackage` is enough; the extraction tooling threads entity metadata across module boundaries.

External (non-Apple) library sources are still not supported - only first-party `AppIntentsPackage` conformers.

## UIKit lifecycle: `UISceneAppIntent` and `AppIntentSceneDelegate`

iOS 26+. For UIKit apps (or UIKit-scene-based Catalyst / iPad apps), two protocols give intents first-class scene awareness:

### `UISceneAppIntent`

Conform the intent when it should receive the `UIScene` that triggered it, so `perform()` can route scene-specific behavior:

```swift
struct OpenInNewWindowIntent: AppIntent, UISceneAppIntent {
    static let title: LocalizedStringResource = "Open in new window"

    @Parameter var target: NoteEntity

    func perform() async throws -> some IntentResult {
        let scene = try currentScene   // provided by UISceneAppIntent
        // route into the specific scene
        return .result()
    }
}
```

### `AppIntentSceneDelegate`

Make the scene delegate aware of intent activations so it can configure window state before the intent fires:

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate, AppIntentSceneDelegate {
    func windowScene(_ scene: UIWindowScene, performActionFor intent: any AppIntent) async {
        // prepare UI for the incoming intent
    }
}
```

On SwiftUI lifecycle apps, this is unnecessary - the `App.init()` / `@Dependency` pattern covers it.

## Scene routing for `TargetContentProvidingIntent`

iOS 26+. When a `TargetContentProvidingIntent` runs, the system needs to know *which* of the app's scenes should handle it. Two mechanisms:

### `contentIdentifier` + `handlesExternalEvents`

The intent declares a `contentIdentifier`; each scene declares which identifiers it accepts:

```swift
extension OpenNoteIntent: TargetContentProvidingIntent {
    var contentIdentifier: String { "note-detail" }
}

// In SwiftUI
WindowGroup {
    NoteDetailView(...)
}
.handlesExternalEvents(matching: ["note-detail"])
```

The system picks the scene whose `handlesExternalEvents` matches the intent's identifier.

### Per-view conditions

For dynamic conditions (e.g., only the scene currently showing a specific entity should handle the intent), attach `.handlesExternalEvents` to the subview rather than the `WindowGroup`.

When `contentIdentifier` is omitted, it defaults to the intent's type name.
