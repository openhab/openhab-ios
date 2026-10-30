# Siri and Apple Intelligence integration

With the 27 releases (WWDC 2026), Siri - powered by Apple Intelligence - can do three new things with your app, all through App Intents:

1. **Access your entities** - answer "when and where is my next meeting?" by reading the real content in your app.
2. **Take action** - "send my latest report to Mary" runs your intent; Siri handles the language, your app does the work.
3. **Understand onscreen context** - "explain this", "email the people in this event" resolve against what's visible.

This file is the map of that integration layer. The mechanics live in neighbouring files:

- Schema adoption (`@AppEntity(schema:)`, `@AppIntent(schema:)`, domains, Xcode snippets) → `assistant-schemas.md`.
- Onscreen awareness and content transfer → `onscreen-awareness.md`.
- Testing → `testing-intents.md`.

## The shape of it

Everything starts with `AppEntity` - a structured description of content you already have (a message, an event, a photo). An entity describes *what the thing is*, *how it's identified*, and *which properties matter*. It is not a new data model; it's a lens on your existing one.

An entity alone isn't enough for Siri to reason about it. Conform it to an **app schema** so Siri knows the *category* (`messages`, `calendar`, `photos`, ...) and can reason in shared terms instead of treating your app as a black box. Then expose **actions** as `AppIntent`s; conform the ones Siri should execute to schema intents (`@AppIntent(schema: .messages.sendMessage)`), and Siri can run them from natural language without you writing phrases.

```
AppEntity            → describes your content
  + AppSchema        → Siri understands what category it is
AppIntent            → exposes an action to the whole system
  + AppSchema        → Siri can execute the action from speech
```

## Finding content: three paths

Before Siri can act on content, it has to *find* it. Pick per entity type - you can mix them across your app.

### 1. Semantic index (preferred): `IndexedEntity`

Conform to `IndexedEntity` and donate to Spotlight with `CSSearchableIndex.default().indexAppEntities(_:)`. This populates the **semantic index**, which gives Siri meaning-based matching, relationships between entities, and the ability to answer questions over content - not just exact-string retrieval.

```swift
// "Show the messages with Flare about movies" - semantic, not a string match.
struct MessageEntity: IndexedEntity {
    @ComputedProperty(indexingKey: \.contentDescription)
    var body: String { message.body }
    // ...
}
```

Keep the index live: index on create, re-index when a property used in the display representation changes, delete on removal. See `spotlight.md` for the indexing strategies and the new `IndexedEntityQuery` reindexing protocol.

This is the **primary** way Siri retrieves your content. Adopt it unless you can't.

### 2. Structured search: `IntentValueQuery`

When a dataset is too large, server-side, or too volatile to index ahead of time, implement `IntentValueQuery`. It's like an `EntityQuery`, with two differences: the system hands you a **structured search input**, and you can return **more than one entity type** (via `@UnionValue`).

```swift
struct AudioEntityQuery: IntentValueQuery {
    @Dependency var library: MusicLibrary

    func values(for input: AudioSearch) async throws -> [AudioEntity] {
        switch input.criteria {
        case .searchQuery(let term):
            return try await library.search(term)          // the relevant part of what was said
        case .unspecified:
            return try await library.likedSongs()           // "Play CosmoTunes" - just play something
        case .url(let url):
            return try await library.item(at: url)          // "Play that playlist Glow sent me"
        @unknown default:
            return []
        }
    }
}

@UnionValue
enum AudioEntity {
    case song(SongEntity)
    case playlist(PlaylistEntity)
}
```

`AudioSearch.criteria` (and the per-domain search-input types) carry the structured query. Handle the cases that make sense for your domain; check the docs for the full criteria set.

### 3. In-app search: `.system.searchInApp`

When the user wants to *find*, not act ("show me running playlists in CosmoTunes"), Siri's default is a generic result list. To route results into your own search UI instead, adopt the system search schema:

```swift
@AppIntent(schema: .system.searchInApp)
struct SearchInAppIntent: ShowInAppSearchResultsIntent {
    var criteria: StringSearchCriteria
    @Dependency var navigation: NavigationManager

    @MainActor
    func perform() async throws -> some IntentResult {
        navigation.openSearch(with: criteria.term)
        return .result()
    }
}
```

`.system.searchInApp` is the **new name** for the `.system.search` schema introduced in iOS 17. It lives in the System app-schema domain and works regardless of which other domains you adopt, even if you index nothing.

## Shaping Siri's response

By default Siri composes its own response. You customise it for personality and clarity.

- **Let Siri handle it.** Return an empty `IntentResult` and Siri writes the response.
- **Custom dialog.** Add `ProvidesDialog` and return an `IntentDialog(full:supporting:)`. Siri **reads the `full` string** on voice-only devices (AirPods, HomePod) and **shows the `supporting` string** with UI. The `full` string must stand on its own as spoken language. (See `fundamentals.md` for dialog and grammar agreement.)
- **Clarifying questions mid-run.** Ask for a value before finishing with `$param.requestValue(...)` - e.g. ask the user to name a new timer when one is already running. Ask sparingly; every question is friction. (See `parameters.md`.)
- **Visuals.** An entity's `DisplayRepresentation` (title + subtitle + image) is reused everywhere - responses, disambiguation between similar entities, answers to questions, Spotlight, Shortcuts, *and confirmation dialogs*. Invest in it once. For a fully custom result card, return `ShowsSnippetView` (see `open-and-snippet-intents.md`).

## Interaction donations (`IntentDonationManager`)

The system already learns from intents the user runs through Siri and Shortcuts - those are donated automatically. What it **can't** see is the user doing the same action through your app's own UI. Donating those UI interactions teaches Apple Intelligence the user's patterns, so it can later infer (for example) which messaging app a person prefers for a given contact.

The clean pattern: the UI and the schema intent both call one shared helper; the helper takes a flag so it only donates the **UI** path.

```swift
func sendMessage(_ body: String, to contact: ContactEntity, donateInteraction: Bool) async throws {
    let message = try await messenger.send(body, to: contact)

    if donateInteraction {
        var intent = SendMessageIntent()
        intent.recipient = contact
        intent.content = body
        IntentDonationManager.shared.donate(intent: intent, result: .resolved(value: message.entity))
    }
}
```

- Donate **after** the action completes, with as much detail as you can. Include a result value when the action produces something interesting.
- Donate UI interactions only - don't re-donate intents the system already donated for you.
- **Don't over-donate.** If your app floods the system, it may start ignoring your donations. Make donations reflect real, completed user behaviour.
- **Delete stale donations** with `deleteDonations(matching:)` when the underlying data is removed or the user undoes the action - it improves future suggestions.

### Donations keep Siri aware of ongoing activities

Some intents start or stop a stateful activity. Donating these lets Siri act on the *current* one. A `NavigationSession` started from your Maps-domain app's UI is donated, so when the user gets in the car and says "add a stop on the way", Siri knows which session is live. Same for stopwatches in the Clock domain (start/stop/pause/lap). Donate the start and stop so Siri can target the active activity.

## Confirmation and ownership

Large language models can misfire, so Siri **automatically asks for confirmation** before intents with meaningful side effects - especially destructive or outward-facing ones.

By default Siri assumes your entities are **private** to the user, and may skip confirmation for them (updating a personal event is low-stakes). But updating something the user has **shared or made public** deserves a prompt. Tell Siri which entities those are by conforming to `OwnershipProvidingEntity` (iOS 27+):

```swift
@AppEntity(schema: .photos.album)
struct PhotoAlbumEntity: OwnershipProvidingEntity {
    let id = UUID()
    var isSharedWithFamily: Bool
    var isPublicAlbum: Bool
    // ... schema properties ...

    var ownership: EntityOwnership {
        var ownership: EntityOwnership = []
        if isSharedWithFamily { ownership.insert(.shared) }
        if isPublicAlbum      { ownership.insert(.public) }
        return ownership
    }
}
```

- Add the protocol **only** to entities the user can actually share or publish.
- Keep `ownership` current - the system reads it whenever it requests the entity, and uses it (plus the entity's `DisplayRepresentation`) when deciding whether and how to confirm.

For the broader trust/risk story, see Apple's "Secure your app: Mitigate risks to agentic features."

## A schema can require its siblings (Xcode tells you)

Some Siri flows need more than one schema to be complete. If you adopt `.messages.sendMessage` but not `.messages.draftMessage`, the **build fails** with a diagnostic - sending a message via Siri needs a draft step for confirmation. This is a design hint surfaced at compile time, not runtime. Click the error and Xcode offers a **fix-it** that generates a correctly-wired stub adoption of the missing schema; you fill in the app-specific pieces (connect entities, inject dependencies, process input, open the right view). Mutating UI state means marking that `perform()` `@MainActor`.

Treat these build errors as a checklist for a complete integration, not an obstacle.

## Validation flow

Test in this order - cheap and isolated first, full system last:

1. **`AppIntentsTesting`** - exercise intents, entities, and queries out-of-process with no Siri involved. Fastest, most reliable; runs in CI. See `testing-intents.md`.
2. **Shortcuts app** - validate the *shape* of each intent: parameters, inputs, how it's presented.
3. **Spotlight** - confirm entities are indexed, discoverable, and linkable, so Siri can find the right data before acting.
4. **Siri** - the full end-to-end: natural language, entity resolution, onscreen context, cross-app workflows. Test on device.

## Getting started checklist

1. Model content as `AppEntity`; conform to the matching app schema.
2. Index entities into Spotlight (`IndexedEntity`); add `IntentValueQuery` for data you can't index.
3. Expose actions as schema intents; let Siri drive the language.
4. Adopt `Transferable` / `IntentValueRepresentation` for cross-app content (see `onscreen-awareness.md`).
5. Annotate views and system integrations with entities for context.
6. Add `OwnershipProvidingEntity` to shareable entities so confirmations are right.
7. Donate UI interactions once the fundamentals work.
8. Test early with `AppIntentsTesting`, then Shortcuts → Spotlight → Siri.
