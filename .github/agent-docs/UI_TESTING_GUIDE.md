# UI Testing Guide

UI tests are **always recommended** alongside any new or modified UI surface. This document explains how `openHABUITests` is wired up, how to inject test state into the app, how to write assertions, and what pitfalls to avoid based on hard-won experience.

---

## Target setup — `membershipExceptions`

`openHABUITests` does **not** use Xcode's default file-system-synchronised discovery. It uses a `PBXFileSystemSynchronizedBuildFileExceptionSet` in `project.pbxproj` (exception set `2FD4E2CF2F66F9F700EBB340`). This means **every new test file must be added explicitly** to the `membershipExceptions` list, otherwise Xcode silently ignores it and the tests are never compiled or run.

```
// project.pbxproj — inside exception set 2FD4E2CF2F66F9F700EBB340
membershipExceptions = (
    MyNewUITests.swift,
    NotificationInteractionUITests.swift,
    OpenHABUITests.swift,
    SnapshotHelper.swift,
    ToastUITests.swift,
);
```

The easiest way to add a file is with a Python one-liner that edits the raw bytes (the indentation uses real tabs, not spaces — the Edit tool normalises whitespace and silently fails to match):

```bash
python3 -c "
with open('openHAB.xcodeproj/project.pbxproj', 'rb') as f: c = f.read()
old = b'\t\t\t\tNotificationInteractionUITests.swift,'
new = b'\t\t\t\tMyNewUITests.swift,\n\t\t\t\tNotificationInteractionUITests.swift,'
assert old in c
open('openHAB.xcodeproj/project.pbxproj', 'wb').write(c.replace(old, new, 1))
"
```

---

## Injecting test state — `launchEnvironment`

The app reads `ProcessInfo.processInfo.environment` at launch. Set keys on `app.launchEnvironment` **before** calling `app.launch()`.

### Defined keys

| Key | Effect |
|-----|--------|
| `UITest` = `"1"` | Forces demo mode, skips onboarding. **Set this in every test.** |
| `UITestToastTitle` | Toast title to show 0.5 s after launch |
| `UITestToastMessage` | Toast message body |
| `UITestToastActions` | JSON-encoded `[{"title":"…","action":"…"}]` for toast action buttons |
| `UITestNotifications` = `"1"` | Auto-opens the Notifications sheet with mock data 0.5 s after launch |

### App-side hook (inside `#if DEBUG`)

Every new test surface needs a corresponding `#if DEBUG` block that reads the environment and sets up state. Keep the injection inside `.onAppear` or a `.task`, use `DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)` for UI that needs a brief settle time after launch:

```swift
#if DEBUG
.onAppear {
    let env = ProcessInfo.processInfo.environment
    if let raw = env["UITestMyFeature"] {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // set up state
        }
    }
}
#endif
```

For views that require mock network data (e.g. `NotificationsView`), add a branch in the `init` that returns early with fixture data:

```swift
#if DEBUG
if ProcessInfo.processInfo.environment["UITestNotifications"] != nil {
    loadNotifications = { [ /* fixture notifications */ ] }
    return
}
#endif
```

---

## Test class structure

```swift
@MainActor
final class MyFeatureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false   // stop on first failure — saves time
        app = XCUIApplication()
        app.launchEnvironment["UITest"] = "1"
    }

    override func tearDown() { app = nil; super.tearDown() }

    // Group fixtures in a private enum to avoid magic strings
    private enum Fixture {
        static let title = "UITest My Feature"
    }
}
```

---

## Helper patterns

### Wait for existence

```swift
@discardableResult
private func waitFor(_ text: String, timeout: TimeInterval = 4) -> XCUIElement {
    let el = app.staticTexts[text]
    XCTAssertTrue(el.waitForExistence(timeout: timeout), "Expected '\(text)' within \(timeout)s")
    return el
}

private func waitForButton(_ label: String, timeout: TimeInterval = 4) -> XCUIElement {
    let el = app.buttons[label]
    XCTAssertTrue(el.waitForExistence(timeout: timeout), "Expected button '\(label)' within \(timeout)s")
    return el
}
```

### Screen frame

Do **not** use `XCUIScreen.main.bounds` — it does not exist in XCTest. Use the app's key window instead:

```swift
private var screen: CGRect { app.windows.firstMatch.frame }
```

### Assert disappearance

Use `NSPredicate` + `expectation(for:evaluatedWith:)` — do not busy-poll or `sleep`:

```swift
let gone = NSPredicate(format: "exists == false")
let ex = expectation(for: gone, evaluatedWith: app.staticTexts["My Title"])
wait(for: [ex], timeout: 2)
```

### Assert within screen bounds

```swift
private func assertWithinScreen(_ el: XCUIElement, label: String) {
    let f = el.frame; let s = screen
    XCTAssertGreaterThanOrEqual(f.minX, s.minX, "\(label) left edge")
    XCTAssertLessThanOrEqual(f.maxX, s.maxX,    "\(label) right edge")
}
```

---

## Layout assertions

When verifying positioning (e.g. right-aligned controls, bottom-anchored banners), use **proportional thresholds** derived from `screen`. Hard-coded pixel values break on different device sizes; tight thresholds break on minor spacing changes. A tolerance of ~10–15 % of the relevant dimension is usually right.

```swift
// Element must be in the right half of the screen
XCTAssertGreaterThan(button.frame.minX, screen.width * 0.45)

// Element must be in the lower half of the screen
XCTAssertGreaterThan(title.frame.minY, screen.height * 0.5)

// Two elements must share roughly the same vertical centre (horizontal layout)
XCTAssertLessThan(abs(button.frame.midY - title.frame.midY), 30)
```

### How to measure first

When writing layout assertions for a new surface, add a **temporary** measurement test to print the real coordinates, run it once, then delete it:

```swift
// Temporary — delete after recording values
func testMeasureLayout() {
    app.launchEnvironment["UITestMyFeature"] = "1"
    app.launch()
    let el = app.staticTexts["My Label"]
    XCTAssertTrue(el.waitForExistence(timeout: 4))
    let s = app.windows.firstMatch.frame
    print("MEASURE screen w=\(s.width) h=\(s.height)")
    print("MEASURE el x=\(el.frame.minX) y=\(el.frame.minY) w=\(el.frame.width) h=\(el.frame.height)")
}
```

Run with:
```bash
xcodebuild test -workspace openHAB.xcworkspace -scheme openHABUITests \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:openHABUITests/MyFeatureUITests/testMeasureLayout 2>&1 | grep MEASURE
```

---

## Running UI tests

```bash
# Full UI test suite
xcodebuild test -workspace openHAB.xcworkspace -scheme openHABUITests \
  -destination "platform=iOS Simulator,name=iPhone 17"

# Single class
xcodebuild test -workspace openHAB.xcworkspace -scheme openHABUITests \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:openHABUITests/ToastUITests

# Single method
xcodebuild test -workspace openHAB.xcworkspace -scheme openHABUITests \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:openHABUITests/ToastUITests/testShortToastAppears
```

If `"iPhone 17"` is unavailable, list available destinations:
```bash
xcodebuild -workspace openHAB.xcworkspace -scheme openHABUITests \
  -showdestinations 2>&1 | grep "iOS Simulator"
```

---

## Lessons learned

### SwiftUI layout inside `.overlay(alignment:)`

An `.overlay(alignment: .bottom)` modifier proposes the **full parent size** (often the full screen height) to its content. A `Divider()` inside an `HStack` inside such an overlay will expand to fill the proposed height, making the banner span the entire screen instead of hugging its content.

**Fix**: add `.fixedSize(horizontal: false, vertical: true)` to the `HStack` before `.padding()`. This tells the stack to use its children's ideal (content-fitting) height instead of the proposed height.

```swift
HStack { ... }
    .fixedSize(horizontal: false, vertical: true)  // ← prevents Divider expansion
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
```

### Transient views vanish before `ui_describe_all` sees them

MCP tools like `ui_describe_all` and `screenshot` inspect a snapshot of the accessibility tree. If the UI auto-dismisses (e.g. a toast with a 5-second timer), the element may already be gone by the time the snapshot is taken. Write XCTest assertions instead — they run inside the app process and can reliably observe short-lived state. Only use `ui_describe_all` for elements that stay on screen.

### Button taps take priority over parent `onTapGesture`

In SwiftUI, a `Button` or `Menu` inside a view that also has `.onTapGesture` will consume the tap before it reaches the gesture recogniser. You do not need to remove the parent gesture to make action buttons work — just embed them in the view normally.

### Membership exceptions — watch for silent omission

If a new UI test file is not added to `membershipExceptions`, it compiles successfully but is never executed. The test run reports zero tests for that file without any warning. Always verify a new test file appears in the test output before trusting a "all tests passed" result.

### Fixture strings must be unique in the demo sitemap

Demo mode is active during UI tests (key `UITest = "1"`). The demo sitemap already contains many labels. Always prefix fixture strings with `UITest ` (e.g. `"UITest Front Door Alert"`) to avoid collisions with real sitemap content that would cause `waitForExistence` to resolve against the wrong element.

### Layout assertions must be proportional, not pixel-perfect

Pixel-exact coordinates change with OS updates, dynamic type, and device form factors. Use `screen.width` / `screen.height` fractions and allow generous tolerances (e.g. ±30 pt for vertical alignment). The goal is catching gross regressions (element on wrong side, element near screen top instead of bottom), not enforcing pixel-level precision.
