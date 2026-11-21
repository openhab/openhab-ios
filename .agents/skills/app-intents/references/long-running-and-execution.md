# Long-running intents and execution targets

WWDC 2026 (the 27 releases) added three APIs that change *how long* an intent can run, *what happens when it stops*, and *which process runs it*. They're orthogonal - mix as needed.

## The 30-second budget

When an intent runs from Siri, Shortcuts, a widget button, or any system surface, the system gives it **30 seconds** to finish. Past that, it's killed. This is enough for everyday actions (toggle a setting, create a note, fetch a small list) but not for uploads, large file operations, data sync, or on-device ML inference.

macOS is the exception - background tasks there run without a hard time limit. On iOS, iPadOS, tvOS, visionOS, and watchOS the 30-second cap applies unless you adopt `LongRunningIntent`.

## `LongRunningIntent` (iOS 27+)

`LongRunningIntent` refines `ProgressReportingIntent`. It extends background execution time and manages the app's background-task lifecycle for you. Progress automatically surfaces as a **Live Activity** with a stop button.

```swift
import AppIntents

struct UploadFileIntent: LongRunningIntent {
    static let title: LocalizedStringResource = "Upload Large File"

    @Parameter(title: "File")
    var file: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Wrap the slow work in performBackgroundTask to get extended runtime.
        let result = try await performBackgroundTask {
            progress.totalUnitCount = 100
            progress.localizedDescription = "Uploading file"

            for chunk in 0..<100 {
                try Task.checkCancellation()
                await uploadChunk(chunk)
                progress.completedUnitCount = Int64(chunk + 1)
                progress.localizedAdditionalDescription = "\(chunk + 1)% complete"
            }
            return "Upload complete!"
        }

        return .result(value: result)
    }

    private func uploadChunk(_ chunk: Int) async { /* ... */ }
}
```

Rules:

- **Do the slow work inside `performBackgroundTask { ... }`.** That closure is what runs with the extended budget. Code outside it still runs under the normal limit.
- **Report progress regularly** via the inherited `progress` property (`totalUnitCount`, `completedUnitCount`, `localizedDescription`, `localizedAdditionalDescription`). If you go quiet, the system assumes the task stalled and **cancels the runtime extension early**. Progress reporting is not optional decoration here - it's the heartbeat that keeps the extension alive.
- `progress` is a Foundation `Progress` object (from `ProgressReportingIntent`, iOS 17+). The same object drives the Live Activity.
- `performBackgroundTask(options:operation:)` takes an optional `LongRunningTaskOptions`; the no-argument form is the common case.

### Background GPU access

`LongRunningIntent` can request **background GPU access** on supported devices - for photo processing, on-device inference, or other Metal/Core ML work that would normally be suspended in the background. Add the GPU-access entitlement to the app; without the entitlement the GPU work is throttled when backgrounded.

### When to reach for it

Adopt `LongRunningIntent` the moment an intent might exceed 30 seconds. Don't try to beat the clock by chunking work into multiple intents or detaching unmanaged `Task`s - a detached task isn't covered by the background-execution extension and gets suspended when the app backgrounds.

## `CancellableIntent` (iOS 26.4+)

A long-running intent *will* be cancelled sometimes - the user taps stop on the Live Activity, the system times out, or it needs to reclaim resources. `CancellableIntent` gives you a typed callback with the **reason**, so you can clean up gracefully (roll back a partial upload, cancel in-flight requests, save intermediate state).

```swift
struct ProcessPaymentIntent: AppIntent, ProgressReportingIntent, CancellableIntent {
    static let title: LocalizedStringResource = "Process Payment"

    @Parameter var amount: Decimal
    @Parameter var paymentMethod: PaymentMethod

    @Dependency var paymentService: PaymentService

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let transactionID = UUID()

        return try await withIntentCancellationHandler {
            try await paymentService.initiateTransaction(transactionID, amount: amount)
            try await paymentService.authorize(transactionID, method: paymentMethod)
            try await paymentService.process(transactionID)
            return .result(dialog: "Payment of \(amount) processed successfully.")
        } onCancel: { reason in
            switch reason {
            case .timeout:        try? await paymentService.rollback(transactionID, reason: "timeout")
            case .userCancelled:  try? await paymentService.cancel(transactionID, reason: "user_cancelled")
            default:              try? await paymentService.cancel(transactionID, reason: "unknown")
            }
        }
    }
}
```

Notes:

- Wrap the work in `withIntentCancellationHandler(operation:onCancel:isolation:)`. The `onCancel` closure receives an `IntentCancellationReason` (`.timeout`, `.userCancelled`, ...).
- If you **don't** care about the reason, Swift's standard `withTaskCancellationHandler(handler:operation:)` is enough - `CancellableIntent` is specifically for when you need the reason *and* extra time to clean up.
- The system can cancel for two reasons worth designing around: the intent went over 30 seconds without reporting progress, or someone tapped cancel in Siri / a Live Activity / Shortcuts.
- **Keep the cancellation handler fast.** Except on macOS, the process can still be suspended shortly after cancellation - adopting the protocol buys extra time, but not unlimited time. Do the minimum (roll back, persist, log) and return.

`CancellableIntent` and `LongRunningIntent` compose: a long-running upload that also wants graceful cancellation conforms to both. When an intent adopts both, you don't need a separate `withIntentCancellationHandler` - `performBackgroundTask` itself takes a trailing `onCancel:` closure, so the extended-runtime work and its cleanup live in one call:

```swift
struct UploadPhotoIntent: LongRunningIntent, CancellableIntent {
    static let title: LocalizedStringResource = "Upload Photo"

    @Parameter var photo: IntentFile

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await performBackgroundTask {
            let chunks = calculateChunks(for: photo)
            progress.totalUnitCount = Int64(chunks)

            for chunk in 1...chunks {
                try Task.checkCancellation()
                try await uploadChunk(chunk)
                progress.completedUnitCount = Int64(chunk)
            }
            return "Upload complete!"
        } onCancel: { reason in
            cleanup(for: reason)   // reason is an IntentCancellationReason
        }
        return .result(dialog: "\(result)")
    }
}
```

## Execution targets: `allowedExecutionTargets` (iOS 27+)

As an app grows, intents often live in a **shared Swift package or framework** imported by the main app *and* a widget extension *and* an App Intents extension. When a request comes in, the system has to pick a process to run the intent in. Its default heuristics: prefer the main app if it's already running; otherwise launch the lighter extension.

Sometimes that's wrong. Classic case: a widget has read-only access to the shared data store and the main app owns all writes (two processes writing the same store invites conflicts). A "favorite this" button in the widget *must* run its intent in the **main app** so the write lands in the right place.

`allowedExecutionTargets` overrides the heuristics:

```swift
struct FavoritePhotoIntent: AppIntent {
    static let title: LocalizedStringResource = "Favorite Photo"
    static let isDiscoverable: Bool = false

    // Force this intent to run in the main app, never the widget extension,
    // because only the main app is allowed to write the shared store.
    static var allowedExecutionTargets: IntentExecutionTargets { [.app] }

    @Parameter var photo: PhotoEntity
    @Dependency var library: PhotoLibrary

    func perform() async throws -> some IntentResult {
        try await library.toggleFavorite(photo.id)
        return .result()
    }
}
```

`IntentExecutionTargets` lets you target the main app, an App Intents extension, a WidgetKit extension, or any combination. By default an intent can run against any target; set this property only to constrain it.

Decide a target when:

- **Write ownership matters** - route mutations to the single process that owns the data store; leave reads on whichever process is cheapest.
- **A dependency only exists in one process** - if an intent needs something registered only in the main app's `App.init()`, it can't run in a widget extension that never built it.
- **Cost matters** - keep cheap read-only intents eligible for the extension (no app launch) and reserve the main app for intents that genuinely need it.

See `dependencies.md` for the app-vs-extension process-boundary rules these targets sit on top of, and `open-and-snippet-intents.md` for the App Group sharing pattern when a widget-fired intent and the widget's timeline provider run in different processes.

## Quick reference

| Need | API | Min OS |
|---|---|---|
| Show a progress bar; finish within 30s | `ProgressReportingIntent` | iOS 17 |
| Run past 30s in the background | `LongRunningIntent` (+ `performBackgroundTask`) | iOS 27 |
| Clean up with the cancellation reason | `CancellableIntent` (+ `withIntentCancellationHandler`) | iOS 26.4 |
| Pin the intent to a specific process | `allowedExecutionTargets` | iOS 27 |
| Conditionally foreground the app | `supportedModes` + `continueInForeground` (see `fundamentals.md`) | iOS 26 |
