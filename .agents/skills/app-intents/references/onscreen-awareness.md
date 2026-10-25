# Onscreen awareness and content transfer

Two capabilities turn "what the user is looking at" into something Siri / Apple Intelligence can act on:

- **Onscreen awareness** - tell the system *which entities* are visible and *where*, so a user can say "edit this", "the third one", "the people in this event" without naming anything.
- **Content transfer** - export your entities as types other apps understand, and import content other apps hand you. This is what makes "text my wife this conversation" or "get directions to this landmark" cross the app boundary.

Both are built on `AppEntity`. The system already knows the raw text on screen from the pixels; annotations add the *structured* layer - which entity each piece of UI represents, and which properties and actions apply. Requires iOS 18.2+; the collection and custom-canvas refinements below arrived with the 27 releases (WWDC 2026).

## The four onscreen-awareness APIs

Pick by how many entities are visible and how they're drawn.

### 1. `NSUserActivity` - one primary item

Use when a screen is dedicated to a single thing (a document, the currently playing track, one event's detail view). Attach `.userActivity` and set its `appEntityIdentifier`:

```swift
struct EventDetailView: View {
    let event: EventEntity

    var body: some View {
        DetailLayout(event: event)
            .userActivity("com.example.CometCal.ViewingEvent", element: event) { event, activity in
                activity.title = "Viewing an event"
                activity.appEntityIdentifier = EntityIdentifier(for: event)
            }
    }
}
```

Siri resolves "this event" / "when is it?" / "where is it?" to exactly the one on screen. `NSUserActivity` is also the back-compat path for older OS versions where the newer annotation modifiers aren't available.

### 2. View entity annotation - one item among a handful

When a screen shows a small fixed set of entities (a couple of cards, a short list rendered as discrete views), attach `.appEntityIdentifier(_:)` to each view that represents an entity:

```swift
ForEach(events) { event in
    EventRow(event: event)
        .appEntityIdentifier(EntityIdentifier(for: event))
}
```

The system now knows which view maps to which entity. "Email the people in the second one" resolves.

### 3. Collection annotation - many entities, lazily

Per-row `.appEntityIdentifier` works for a handful, but attaching one to *every* row in a long list is wasteful, and the annotation disappears the instant a row scrolls out of the view hierarchy. For lists and collections, annotate the **container** and let the system fetch identifiers lazily:

```swift
List(selection: $selection) {
    ForEach(tracks) { track in
        TrackRow(track: track)
    }
}
.appEntityIdentifier(forSelectionType: Track.ID.self) { selectionID in
    EntityIdentifier(for: TrackEntity.self, identifier: selectionID)
}
```

Advantages over per-row annotations:

- The system fetches identifiers **on demand**, not for every visible row up front.
- It can discover entities the user **selected and then scrolled off screen** - per-row annotations would already be gone.

Use this for any `List` / collection that can hold more than a handful of items.

### 4. Custom canvas annotation - non-standard drawing

When content is drawn in a single `Canvas`, a `CALayer`, or another non-view-per-entity surface, there's no view to attach an identifier to. Supply the entities through a closure with `.appEntityUIElements(_:)`:

```swift
Canvas { context, size in
    notes.forEach { context.fill(Path(roundedRect: $0.frame, cornerSize: .zero), with: .color($0.colorFill)) }
}
.appEntityUIElements { context in
    notes.compactMap { note in
        let wanted = context.requests.contains { request in
            switch request {
            case .visible(let rect): return note.frame.intersects(rect)
            case .selected:          return note.isSelected
            @unknown default:        return false
            }
        }
        guard wanted else { return nil }
        return AppEntityUIElement(
            identifier: EntityIdentifier(for: StickyNote.self, identifier: note.id),
            bounds: note.frame,
            state: .init(isSelected: note.isSelected)
        )
    }
}
```

The system passes a context whose `requests` ask for either the **visible** entities in a rectangle or the **selected** ones; you return an `AppEntityUIElement` (identifier + bounds + selection state) per matching item. This is how a custom waveform, piano-roll, map canvas, or freeform board participates in onscreen awareness.

### UIKit / AppKit

All four APIs have non-SwiftUI equivalents:

- **Single / per-item:** any responder conforms to `AppEntityAnnotatable` - set its `appEntityIdentifier` property.
- **Custom drawing:** set the view's `appEntityUIElementProvider` closure (same `context.requests` shape as `.appEntityUIElements`).
- **Collections:** adopt `UICollectionViewAppIntentsDataSource` / `UITableViewAppIntentsDataSource` (and the `NS*` variants on macOS) so the data source supplies entity identifiers lazily.

These also power contextual menu items in UIKit apps - see Apple's "Modernize your UIKit app."

## Make onscreen understanding fast: `displayRepresentations`

When a screen shows many entities, Siri has to understand them *quickly* to answer "play the third one" - if resolution is slow it may give up, ask to clarify, or do the wrong thing. Don't make it fetch full entities from your database just to read a label.

Implement the `displayRepresentations` method on the entity's query so Siri can pull just the text representation. Take a `requestedComponents` parameter so you only materialize what the system actually asked for - `.text` for a plain label, versus the full title/subtitle/image - and skip loading artwork or running queries when only text is needed:

```swift
extension TrackEntityQuery {
    func displayRepresentations(
        for identifiers: [TrackEntity.ID],
        requestedComponents: DisplayRepresentation.Components = .text
    ) async throws -> [TrackEntity.ID: DisplayRepresentation] {
        try await store.trackTitles(for: identifiers).mapValues {
            DisplayRepresentation(title: "\($0)")
        }
    }
}
```

Now resolving onscreen content skips the heavy `entities(for:)` path and the database round-trip when only the display text is needed. Branch on `requestedComponents` to add a subtitle or thumbnail only when the system requests it. Worth adding to any entity that appears in scrollable lists.

## Content transfer: exporting and importing entities

Onscreen awareness lets Siri *identify* an entity. To actually move it into another app's action ("text this", "get directions to this", "summarize this"), the entity must be exportable - and to receive content from another app, importable. Both go through `Transferable`.

### Structured system types: `IntentValueRepresentation` (iOS 26.4+)

`Transferable`'s `FileRepresentation` / `DataRepresentation` cover known file formats (PDF, image, text). They **can't** carry structured types that have no file format - a coordinate, a contact, a person's name. Maps can't navigate to a `.plainText` blob; it needs a `PlaceDescriptor`.

`IntentValueRepresentation` (built with the `ValueRepresentation` builder) bridges your `AppEntity` to a **system intent value** - `IntentPerson`, `PlaceDescriptor` (from GeoToolbox), `PersonNameComponents`, and other `_SystemIntentValue` types - and supports import as well as export. Add it alongside any existing representations:

```swift
struct ContactEntity: AppEntity, Transferable {
    var id: String
    @Property var name: String
    @Property var email: String
    // ... typeDisplayRepresentation, defaultQuery, displayRepresentation ...

    static var transferRepresentation: some TransferRepresentation {
        IntentValueRepresentation(
            exporting: { contact in
                IntentPerson(
                    identifier: .applicationDefined(contact.id),
                    name: .displayName(contact.name),
                    handle: .init(emailAddress: contact.email)
                )
            },
            importing: { person in
                guard case let .applicationDefined(id) = person.identifier?.value,
                      let handle = person.handle else { throw ConversionError.missingData }
                return ContactEntity(id: id, name: person.name.displayString, email: handle.value)
            }
        )
    }
}
```

Now "call this contact" (export) and "add this person to my app" (import) both work across the app boundary.

**Key-path shorthand.** If the entity already stores the system type as a `@Property`, skip the closure:

```swift
struct LocationEntity: TransientAppEntity, Transferable {
    @Property var place: PlaceDescriptor

    static var transferRepresentation: some TransferRepresentation {
        ValueRepresentation(exporting: \.place)
    }
}
```

Same result as the export closure, far less code. With a `PlaceDescriptor` exported, a landmark entity flows into Maps and the user gets directions - no file conversion in between.

### Resolve to existing vs. import as new

When content arrives **into** your app, you decide whether it refers to something that already exists or something brand new:

- **Resolve to an existing entity → `IntentValueQuery`.** Conceptually an entity query scoped to incoming intent values. "Given this `IntentPerson`, which of my contacts does it refer to?" Use when the incoming value should map onto data you already have.
- **Create a new entity → `IntentValueRepresentation` `importing:`.** Convert the incoming value into a fresh entity (the `importing:` closure above). Use when the content doesn't exist in your app yet.

Many apps do both: resolve if it matches existing data, import if it doesn't. `IntentValueQuery` is also the entry point for Visual Intelligence (`SemanticContentDescriptor` input) and for structured Siri search - see `assistant-schemas.md` and `siri-intelligence.md`.

## Entity annotations on system integrations

Onscreen content isn't the only place a user encounters your entities. Annotate the system integrations you already adopt so Siri can act on the entity behind a notification, the now-playing track, or a firing alarm. Same idea everywhere: attach the entity's `EntityIdentifier`.

- **User Notifications.** Set `appEntityIdentifier` on the `UNMutableNotificationContent` when posting. When the notification is announced on AirPods, the user can reply to the message / check off the reminder it represents.
- **Now Playing.** Add entities to `MPNowPlayingInfoCenter.nowPlayingInfo` under the `MPNowPlayingInfoPropertyAppEntityIdentifiers` key, **ordered most-specific to least-specific** (song, then artist, then playlist). This is what enables "play the live version" - Siri knows the song entity behind what's playing.
- **AlarmKit.** Pass the entity's `appEntityIdentifier` in the `AlarmConfiguration` when creating an alarm or timer, so the user can act on a firing alarm ("snooze it").

These go through the `AppEntityAnnotatable` protocol. Two consequences:

- **You can't use `TransientAppEntity` here.** Transient entities have no persistent identifier, and these integrations key off `EntityIdentifier`. Use a real `AppEntity` (or `IndexedEntity`).
- Adding `AppEntityAnnotatable` conformance to a system type that doesn't already declare it does nothing - only the types Apple has wired (notification content, now-playing info, alarm config) deliver the context.

## Cross-references

- `assistant-schemas.md` - schema adoption, Visual Intelligence `IntentValueQuery` + `SemanticContentDescriptor`.
- `siri-intelligence.md` - the broader Siri/Apple Intelligence integration: finding content, custom responses, donations, confirmation.
- `entities.md` - `Transferable`, `IntentPerson`, `SyncableEntity`, `ValueRepresentation` in context of entity modeling.
