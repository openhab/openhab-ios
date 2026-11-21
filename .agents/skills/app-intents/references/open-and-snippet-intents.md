# Open intents and snippet views

Three shapes for "bring a thing to the user":

- `OpenIntent` - **launch the app and navigate to the thing**. Good when the user wants to interact (edit, reply, continue reading).
- `AppIntent & ShowsSnippetView` - **show a summary right there** with the snippet view returned directly from `perform()`. Good for self-contained one-shot answers.
- `AppIntent & ShowsSnippetIntent` + a separate `SnippetIntent` - **show a summary that stays live and can re-fire**. The business intent returns a value; a paired `SnippetIntent` renders the UI. This is the modern pattern for snippets with interactive content (buttons that fire more intents).

They can coexist; pick per use case.

## `OpenIntent`

`OpenIntent` is a subprotocol of `AppIntent`. It requires a `target` parameter (the entity being opened) and automatically opens the app when the intent completes:

```swift
import AppIntents

struct OpenArticleIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open article"

    @Dependency var navigator: AppNavigator

    @Parameter(title: "Article")
    var target: ArticleEntity     // MUST be named `target`

    func perform() async throws -> some IntentResult {
        try await navigator.navigate(to: target)
        return .result()
    }
}
```

The `target` property name is required; the protocol keys off it. The app is opened automatically *after* `perform()` returns - your job in `perform()` is to update navigation state so that when the app comes to the foreground, the correct screen is on top.

### Navigation wiring

Most apps route navigation through a main-actor-bound controller that drives a `NavigationStack`:

```swift
@Observable @MainActor
final class AppNavigator {
    var path: [Article] = []

    func navigate(to entity: ArticleEntity) async throws {
        let id = entity.id
        let results = try await store.articles(matching: #Predicate { $0.id == id })
        if let article = results.first {
            path = [article]
        }
    }
}
```

```swift
struct ContentView: View {
    @Bindable var navigator: AppNavigator

    var body: some View {
        NavigationStack(path: $navigator.path) {
            ArticleList()
                .navigationDestination(for: Article.self, destination: ArticleEditor.init)
        }
    }
}
```

Inject `AppNavigator` through `@Dependency` so intents can reach it. See `dependencies.md`.

### When the app isn't running

`OpenIntent` works even when the app has never been launched. The app process starts, `App.init()` runs (registering dependencies), the intent fires, navigation state is set, then the window appears on screen already at the right place. This is why **all cross-intent setup belongs in `App.init()`** - not in `.onAppear`, not in view modifiers.

### When the intent runs before the UI is ready

`App.init()` running first doesn't mean everything `perform()` touches exists yet. Apps whose navigation lives in a store created by the root view (TCA `Store`, a coordinator built in `.task`), or that show a splash / onboarding screen first, can receive the intent while there is nothing to navigate. The navigation call is silently lost and the app opens on its home screen.

Route intents through a small main-actor bridge that **queues the action until the app is ready**:

```swift
@MainActor
enum AppIntentRouter {
    enum Action { case openRoute(id: UUID) }

    private static var send: ((Action) -> Void)?
    private static var pending: Action?

    static func dispatch(_ action: Action) {
        if let send { send(action) } else { pending = action }
    }

    /// Call once the store / navigation is live (root view `.task`, end of splash).
    static func attach(_ handler: @escaping (Action) -> Void) {
        send = handler
        if let pending {
            self.pending = nil
            handler(pending)
        }
    }
}

struct OpenRouteIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Route"

    @Parameter(title: "Route")
    var target: RouteEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentRouter.dispatch(.openRoute(id: target.id))
        return .result()
    }
}
```

Two rules that keep this robust:

- **One action for every entry point.** The `OpenIntent`, a Spotlight tap delivered as a user activity (see "Bridging Spotlight selection" below), a widget deep link, and the in-app list row should all end in the same `.openRoute(id:)` action. Opening from Siri then behaves exactly like tapping in the app, and there's one code path to test.
- **Hold the pending value in app state if a splash can intervene.** If the store exists but a splash / paywall is still covering the UI, store the id (`state.pendingRouteID = id`) and apply it when the splash finishes, rather than pushing navigation underneath it.

When your navigator is a plain `@Observable` created in `App.init()` and injected via `@Dependency` (the pattern above), you don't need this - the object already exists when the intent fires.

## Snippet views (inline): `ShowsSnippetView`

A snippet view is a compact SwiftUI scene rendered by the system in response to the intent. The user doesn't leave their current context; they just see the answer.

The inline form returns the view directly from the business intent's `perform()`:

```swift
import AppIntents
import SwiftUI

struct SummarizeArticleIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize article"

    @Parameter(title: "Article")
    var article: ArticleEntity

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        .result(dialog: "\(article.title)") {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.largeTitle)
                Text(article.title).font(.headline)
                Text(article.summary).font(.body)
            }
            .padding()
        }
    }
}
```

The snippet is encoded and transferred like a widget. Don't use `List`, `ScrollView`, or any interactive control that needs a live `UIViewController` behind it - they will either fail to render or behave oddly. Stick to static layout: `VStack`, `HStack`, `Text`, `Image`, `Label`, `Spacer`, backgrounds, padding.

## Snippet intents (indirect): `ShowsSnippetIntent` + `SnippetIntent`

The modern pattern splits concerns: the business intent returns a chainable value; a paired `SnippetIntent` renders the UI. This is the right shape when:

- The snippet contains `Button(intent:)` (see below) so it can re-fire and refresh itself.
- You want the intent to return a value Shortcuts can chain, *and* show a snippet.
- The snippet will be reused from multiple business intents.

```swift
import AppIntents
import SwiftUI

// 1. Business intent: returns a value and references the snippet intent
struct GetCaffeineIntent: AppIntent {
    static let title: LocalizedStringResource = "Get caffeine intake"
    static let description = IntentDescription("Shows how much caffeine you've had today.")

    @Dependency var store: DataStore

    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ShowsSnippetIntent {
        let amount = await store.amountIngested
        return .result(
            value: amount,
            snippetIntent: ShowCaffeineIntakeSnippetIntent()
        )
    }
}

// 2. Snippet intent: not discoverable, only renders UI
struct ShowCaffeineIntakeSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Caffeine snippet"
    static let isDiscoverable: Bool = false

    @Dependency var store: DataStore

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: CaffeineIntakeSnip(store: store))
    }
}

// 3. The view can contain interactive intents
struct CaffeineIntakeSnip: View {
    let store: DataStore

    var body: some View {
        VStack(alignment: .leading) {
            Text("Today's caffeine").font(.subheadline).foregroundStyle(.secondary)
            Text(store.formattedAmount())
                .font(.title)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)

            Text("Quick log").font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Button(intent: LogAmountIntent(amount: 64))  { Text("Single") }
                Spacer()
                Button(intent: LogAmountIntent(amount: 128)) { Text("Double") }
                Spacer()
                Button(intent: LogAmountIntent(amount: 192)) { Text("Triple") }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).gradient)
        .clipShape(.containerRelative)
    }
}
```

When the user taps one of the `Button(intent:)` buttons, the system fires `LogAmountIntent`, then re-runs `ShowCaffeineIntakeSnippetIntent` to refresh the snippet in place. The user never leaves Siri/Shortcuts.

Key rules:

- Mark `SnippetIntent` types with `isDiscoverable = false`. They're an implementation detail; don't pollute the Shortcuts library.
- The snippet intent's `perform()` returns `some IntentResult & ShowsSnippetView`. The view it returns goes through the same "widget-style" render pipeline as inline snippets.
- `.result(value:snippetIntent:)` accepts the snippet intent *instance*, not type - create a new one each time.

## `Button(intent:)` in SwiftUI

SwiftUI ships a `Button` initializer that takes an `AppIntent` and fires it on tap. Works inside:

- Widget views (home, lock screen, StandBy, Control Center).
- App Intent snippet views.
- Live Activities.
- Regular app views (convenient; identical behavior to a plain closure-based button in that context).

```swift
Button(intent: LogAmountIntent(amount: 64)) {
    Text("Single")
}
```

Requirements on the intent:

1. It's an `AppIntent` (or subprotocol).
2. It has a matching convenience initializer so you can construct it parameterized:

```swift
extension LogAmountIntent {
    init(amount: Int) { self.amount = amount }
}
```

3. For buttons inside snippets/widgets, mark it `isDiscoverable = false` unless you also want it in the Shortcuts library.

The intent's `perform()` runs in the app's intent extension context, not the widget's; writes go to the shared data store. After it returns, the host (widget/snippet) re-renders.

### Button style inside snippets

SwiftUI button styles applied to `Button(intent:)` work the same as in regular views. Custom styles animate correctly, including the press/scale effect:

```swift
struct IntentScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.8), .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.86 : 1.0)
            .animation(.easeInOut(duration: 0.24), value: configuration.isPressed)
    }
}
```

### Snippet-only imports

The file producing a snippet needs both frameworks:

```swift
import AppIntents
import SwiftUI
```

### Interactive widgets: the App Group sharing pattern

When `Button(intent:)` lives inside a **widget** view (not a snippet), the intent runs in the app's process while the widget view lives in the widget extension's process. They don't share memory - an in-memory `@Dependency` instance is only visible to one side, and a plain `UserDefaults.standard` write from the intent isn't visible to the widget's timeline provider.

Bridge them with an App Group and `UserDefaults(suiteName:)`:

1. Add the same App Group capability to both the main app target and the widget extension target.
2. Gate shared state behind a helper that reads/writes the suited `UserDefaults`.
3. Let the intent write through it; let the widget's `TimelineProvider` read through it.
4. Reload timelines from the intent when the widget needs refreshing.

```swift
import AppIntents
import WidgetKit

enum SharedCounter {
    private static let defaults = UserDefaults(suiteName: "group.com.example.myapp")!

    static var current: Int {
        defaults.integer(forKey: "count")
    }

    static func increment() {
        defaults.set(current + 1, forKey: "count")
    }
}

struct IncrementCounterIntent: AppIntent {
    static let title: LocalizedStringResource = "Increment counter"
    static let description = IntentDescription("Increments the shared counter.")
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        SharedCounter.increment()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

In the widget:

```swift
struct CounterProvider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = Entry(date: .now, count: SharedCounter.current)
        completion(Timeline(entries: [entry], policy: .never))
    }
    ...
}

struct CounterWidgetView: View {
    let entry: CounterProvider.Entry

    var body: some View {
        VStack {
            Text("Count: \(entry.count)")
            Button(intent: IncrementCounterIntent()) {
                Text("Increment")
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

Why this works:

- Both processes read and write the same defaults suite.
- `WidgetCenter.shared.reloadAllTimelines()` inside the intent forces the widget to re-query the provider, which picks up the new value.
- `@Dependency` can't be used on the widget side (there's no app to run `App.init()` before the widget extension starts), which is why routing through a suited `UserDefaults` (or an App Group file, or a shared SwiftData store) is mandatory - not optional.

When the main app foregrounds, re-read shared state via `@Environment(\.scenePhase)` so in-app views catch up with widget-triggered changes:

```swift
@Environment(\.scenePhase) private var phase
@State private var count = SharedCounter.current

var body: some View {
    Text("Count: \(count)")
        .onChange(of: phase) {
            count = SharedCounter.current
        }
}
```

For larger shared state, swap `UserDefaults` for a `ModelContainer` whose `ModelConfiguration` points at a URL inside the App Group's shared container - the same SwiftData sendability rules from `dependencies.md` still apply.

### Dark mode gotcha

Snippets rendered by Siri do not live-update when the user toggles dark mode *while the snippet is on screen*. Dismissing and triggering again picks up the current appearance correctly.

## Snippet design rules

Snippets are quick-glance overlays. Apple's design guidance (WWDC25 #281):

- **Height ceiling: 340 points.** Content beyond this requires scrolling, which breaks the glanceable-overlay model. Link to the full app for deep content.
- **Type size above system default.** Snippets are viewed from across the room as often as up close; raise the base size.
- **Consistent margins.** Use `ContainerRelativeShape` for backgrounds so margins adapt to the rounded-rectangle container the system draws around snippets.
- **Contrast beyond standard ratios.** Snippets overlay arbitrary backgrounds; ordinary 4.5:1 text-to-background contrast isn't enough. Test at reading distance.
- **Understandable without dialog.** The snippet should convey its meaning on screen alone. Treat dialog as supplementary audio, not the primary channel. Don't duplicate every snippet label in the dialog.

### Result vs confirmation snippet types

Two distinct behaviors, each with a standard button pattern:

- **Result snippet.** Shown after the intent has already completed. One button: **Done**. Use for reporting status (an order was placed, a message was sent).
- **Confirmation snippet.** Shown *before* the intent runs. Needs an action-verb button - **Order**, **Send**, **Post**, **Play**, **Delete**, **Confirm**, or a custom verb. The user's tap is what triggers the real work.

```swift
// Confirmation flow
try await requestConfirmation(
    actionName: .order,   // "Order" button label
    snippetIntent: CoffeeRequestSnippetIntent(order: order)
)
try await orderService.submit(order)

// Result after confirmation
return .result(
    snippetIntent: CoffeeResultSnippetIntent(order: order)
)
```

`actionName` accepts standard verbs (`.order`, `.send`, `.play`, `.delete`, `.confirm`, `.search`) or a custom string; pick the standard verb when one fits so users see consistent language across apps.

## Picking the right shape

| Situation | Pick |
|---|---|
| User will read, interact, edit | `OpenIntent` |
| One-shot summary, no re-fire, no value to chain | `AppIntent & ShowsSnippetView` (inline) |
| Summary with interactive buttons that re-render | `AppIntent & ShowsSnippetIntent` + `SnippetIntent` |
| User wants a value to chain in Shortcuts | `AppIntent & ReturnsValue<T>` |
| Snippet *and* a chainable value | `AppIntent & ReturnsValue<T> & ShowsSnippetIntent` |
| Simple confirmation ("Done") | `AppIntent & ProvidesDialog` |

For "show me my latest note" - a snippet is usually better, because the point is to read it, not to edit it. For "open my latest note so I can keep writing" - use `OpenIntent`.

For "show my dashboard and let me log from it" - use the two-intent snippet pattern, so buttons in the snippet can fire more intents and refresh the view in place.

## Bridging Spotlight selection to `OpenIntent`

When a user taps an app entity in Spotlight results, the system looks for an `OpenIntent` whose `target` matches that entity type and invokes it. As long as:

1. The entity conforms to `IndexedEntity`.
2. The entity has been indexed (see `spotlight.md`).
3. An `OpenIntent` exists with `target: YourEntity`.

...tapping the Spotlight result routes through your `OpenIntent` automatically. No additional wiring.

In simulator this sometimes takes a few minutes after first launch before it starts working reliably - the index builds up in the background. On device it's generally faster.

### Also handle the `CSSearchableItemActionType` user activity

Don't assume every Spotlight tap arrives through `perform()`. A tap can also be delivered the classic Core Spotlight way - as an `NSUserActivity` of type `CSSearchableItemActionType` whose `userInfo[CSSearchableItemActivityIdentifier]` is the item's unique identifier (for an indexed `AppEntity`, the entity's `id` as a string). Expect it for items donated as `CSSearchableItem`s and when no matching `OpenIntent` exists; since the exact delivery path isn't guaranteed, handle both paths and funnel them into the same navigation action:

```swift
import CoreSpotlight

WindowGroup {
    RootView()
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard
                let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                let id = UUID(uuidString: raw)       // parse defensively; log the raw value once to confirm the format
            else { return }
            AppIntentRouter.dispatch(.openRoute(id: id))
        }
}
```

On a **cold launch** in a UIKit-lifecycle app, the activity arrives in `UIScene.ConnectionOptions.userActivities` inside `scene(_:willConnectTo:options:)`, before any SwiftUI view (and its `.onContinueUserActivity`) exists. Read it there and dispatch through the queuing router from "When the intent runs before the UI is ready" so it isn't lost.

## Returning `OpenURLIntent` to open the app post-action

When an intent *creates* something (a new note, a scanned document, a booked reservation) and you want the user to land in the app viewing the result, return an `OpenURLIntent` built from the new entity's URL representation:

```swift
struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create note"

    @Parameter var body: String
    @Dependency var store: DataStore

    func perform() async throws -> some IntentResult & ReturnsValue<NoteEntity> & OpensIntent {
        let note = try store.createNote(body: body)
        return .result(
            value: note.entity,
            opensIntent: OpenURLIntent(URLRepresentation(entity: note.entity))
        )
    }
}
```

The return shape `ReturnsValue<T> & OpensIntent` both hands back the created entity (chainable in Shortcuts) *and* tells the system to open the app to that entity's universal link. Pairs naturally with `URLRepresentableEntity`. iOS 18+.

## iOS 26 snippet interactivity

`SnippetIntent` became the primary interactive-snippet mechanism at iOS 26 (WWDC25 #275). Two refinements worth knowing:

### Interactive refresh cycle

When a button inside a snippet view fires another `AppIntent`, the system:

1. Runs the button's intent to completion.
2. **Re-fetches all `@Parameter` values** of the owning snippet intent (for entity parameters, this re-runs `entities(for:)` on the query).
3. Calls the snippet intent's `perform()` again to re-render.
4. Animates the diff in the displayed view.

This means the snippet intent's `perform()` is **called multiple times** during a single user interaction - once initially, once after each button press, potentially once on appearance changes. It must be pure: fetch state, build the view, return. Do not mutate app state inside `SnippetIntent.perform()`.

### Manual refresh: `SnippetIntent.reload()`

For long-running work that completes asynchronously, you can force a refresh from outside the snippet:

```swift
// Somewhere in the app, when new data arrives
MyDashboardSnippetIntent.reload()
```

The system re-invokes `perform()` on the current snippet if it's still visible. Useful for push-notification-driven dashboards or intents that poll a background process.

### SwiftUI animation

Snippet view mutations animate automatically if you use SwiftUI's standard transition modifiers:

```swift
Text(store.formattedAmount())
    .contentTransition(.numericText())

VStack { ... }
    .animation(.easeInOut, value: store.currentState)
```

## `URLRepresentableEntity` + `URLRepresentableIntent`

If your app already handles universal links to display specific entities, don't write duplicate navigation code in an `OpenIntent.perform()`. Let the system route through your universal-link handler automatically.

Step 1 - declare the URL representation of the entity:

```swift
extension TrailEntity: URLRepresentableEntity {
    static var urlRepresentation: URLRepresentation {
        // Use string interpolation with the entity's identifier
        "https://example.com/trail/\(.id)/details"
    }
}
```

Step 2 - conform the open intent to both `OpenIntent` and `URLRepresentableIntent`, and omit `perform()`:

```swift
struct OpenTrail: OpenIntent, URLRepresentableIntent {
    static let title: LocalizedStringResource = "Open Trail"
    static let description = IntentDescription("Displays trail details in the app.")

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @Parameter(title: "Trail")
    var target: TrailEntity

    // No perform() - the system builds the URL from TrailEntity.urlRepresentation
    // and hands it to your universal-link handler.
}
```

The intent compiles and runs without a `perform()` body. When the user runs the intent, the system:

1. Asks `TrailEntity.urlRepresentation` for the URL, interpolating `\(.id)`.
2. Opens the app with that URL through the standard universal-link path.
3. Your existing `.onOpenURL` / `UIApplication(_:continue:)` / `NSUserActivity` handler navigates to the right scene.

Don't mix modes: if you provide a `perform()`, it runs instead of the URL path. Pick one.

`URLRepresentationConfiguration` (iOS 18+) lets you define named fragments and configure the behavior further; for simple apps, string-literal `URLRepresentation` is enough.

## `TargetContentProvidingIntent`

Marker protocol on iOS that tells the system "this intent's completion produces the scene the user is navigating to." The most common use is making an `OpenIntent` eligible as the final step of a visual intelligence flow (user circles something in the camera, picks a result from your app, the system runs your intent to land them in the right scene):

```swift
struct OpenLandmarkIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Landmark"

    @Parameter(title: "Landmark", requestValueDialog: "Which landmark?")
    var target: LandmarkEntity
}

#if os(iOS)
extension OpenLandmarkIntent: TargetContentProvidingIntent {}
#endif
```

Gate on `#if os(iOS)` - the protocol is iOS-only. Don't skip the conformance when you want visual intelligence to be able to land users inside your app; without it, the system treats the intent as a side-effect action instead of a navigation endpoint.

## Widget configuration intents

Widgets that need user configuration (pick a calendar, pick a folder, pick a stock ticker) back their configuration with a `WidgetConfigurationIntent`:

```swift
struct FolderWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose folder"

    @Parameter(title: "Folder")
    var folder: FolderEntity?
}
```

Pair with WidgetKit's `AppIntentConfiguration` (iOS 17+, replaces `IntentConfiguration`):

```swift
struct FolderWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "FolderWidget", intent: FolderWidgetIntent.self, provider: FolderProvider()) { entry in
            FolderWidgetView(entry: entry)
        }
    }
}
```

The `WidgetConfigurationIntent` is an empty-conformance marker - no `perform()`. Parameter queries populate the widget's configuration picker.

## Control configuration intents

iOS 18's Control Center controls use `ControlConfigurationIntent` the same way. An intent can be both the control's configuration *and* the action it performs on tap:

```swift
struct ToggleFocusIntent: ControlConfigurationIntent, AppIntent {
    static let title: LocalizedStringResource = "Toggle focus"

    @Parameter var mode: FocusMode

    func perform() async throws -> some IntentResult {
        try await focusManager.toggle(mode)
        return .result()
    }
}
```

The system uses the `@Parameter` for the configuration picker when the user adds the control; when the control is tapped, `perform()` runs with that configured value.

### `ControlWidgetButton(action:)`

Inside a control widget's view, use `ControlWidgetButton` to fire an intent on tap. It's the control-widget counterpart to `Button(intent:)`:

```swift
struct FocusControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "focus-toggle") {
            ControlWidgetButton(action: ToggleFocusIntent(mode: .work)) {
                Label("Work Focus", systemImage: "briefcase")
            }
        }
    }
}
```

Takes a pre-configured intent instance (so the same convenience-init pattern from `Button(intent:)` applies). Runs the intent in the app process; respects `openAppWhenRun` and all the usual lifecycle rules.

### Snippets don't render inside Control Center

Control widgets are a different rendering surface than App Intents snippets. Intents fired from `ControlWidgetButton(action:)` can return dialog and mutate state, but **they cannot display a `ShowsSnippetView` / `ShowsSnippetIntent` result inside the control**. The snippet UI is not available in Control Center - WWDC demo footage sometimes suggests otherwise but the shipping behavior is that snippets appear only from Siri, Shortcuts, and Spotlight invocations.

If the intent needs to surface detailed feedback, either:

- Use a short dialog (`.result(dialog: "Work focus on.")`) - Control Center shows it as a brief toast.
- Open the app via `openAppWhenRun = true` or `OpenURLIntent` when a full snippet-like view is required.
- Update the control's displayed state and rely on the control's own rendering to convey the outcome.

## Proactive suggestions: `RelevantIntentManager`

iOS 17+. The Smart Stack (and watchOS complications) can surface your widgets at contextually relevant times. Declare when:

```swift
import AppIntents

let relevant = RelevantIntent(
    FolderWidgetIntent(folder: morningRoutineFolder),
    widgetKind: "FolderWidget",
    relevance: [
        .timeRange(morning),
        .location(home)
    ]
)

try await RelevantIntentManager.shared.updateRelevantIntents([relevant])
```

Provide an intent instance, the widget kind string, and one or more `RelevantContext` predicates (time, location, focus, heart rate for Watch, ...). The system picks among registered intents when building the Smart Stack. Replaces the older `INInteraction` / `INDailyRoutineRelevanceProvider` APIs with a Swift-friendly surface.

Call `updateRelevantIntents` whenever the user's routine changes materially; the system caches the submissions.

## Multi-step interactive confirmation with snippet intents

The snippet-intent pattern (see above) can be extended into a multi-step interactive flow using `requestConfirmation(actionName:snippetIntent:)`. The intent pauses, the system shows a snippet the user can interact with (configure parameters via `Button(intent:)`), and only after they confirm does the intent continue:

```swift
struct FindTicketsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Tickets"

    static var parameterSummary: some ParameterSummary {
        Summary("Find best ticket prices for \(\.$landmark)")
    }

    @Dependency var searchEngine: SearchEngine

    @Parameter var landmark: LandmarkEntity

    func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        let searchRequest = await searchEngine.createRequest(landmarkEntity: landmark)

        // Present a snippet that allows people to change the number of tickets.
        try await requestConfirmation(
            actionName: .search,
            snippetIntent: TicketRequestSnippetIntent(searchRequest: searchRequest)
        )

        // After the user confirms, perform the ticket search.
        try await searchEngine.performRequest(request: searchRequest)

        // Show the result snippet.
        return .result(
            snippetIntent: TicketResultSnippetIntent(searchRequest: searchRequest)
        )
    }
}
```

The request snippet displays configurable fields driven by helper intents:

```swift
struct ConfigureGuestsIntent: AppIntent {
    static let title: LocalizedStringResource = "Configure Guests"
    static let isDiscoverable: Bool = false   // helper only

    @Dependency var searchEngine: SearchEngine

    @Parameter var searchRequest: SearchRequestEntity
    @Parameter var numberOfGuests: Int

    func perform() async throws -> some IntentResult {
        await searchEngine.setGuests(to: numberOfGuests, searchRequest: searchRequest)
        return .result()
    }
}
```

Flow: main intent pauses → request snippet shows → user taps `Button(intent: ConfigureGuestsIntent(...))` to change values → user taps "Search" (confirmation) → main intent resumes → result snippet shown. All without leaving Siri or the Shortcuts panel.

`actionName:` is a standard verb (`.search`, `.send`, `.play`, `.confirm`, `.delete`) that labels the confirmation button.
