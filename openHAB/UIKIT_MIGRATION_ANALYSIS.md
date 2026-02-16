# UIKit to SwiftUI Migration Analysis

## Current State

The openHAB iOS app has already undergone significant SwiftUI migration:

### ✅ Already Migrated to SwiftUI
1. **Root View** - `OpenHABTabRootView` is now the app's root view (set in `AppDelegate`)
2. **Web Views** - Migrated from `OpenHABWebViewController` to `OpenHABWebView` (SwiftUI)
3. **Tab Navigation** - Using SwiftUI `TabView` with `.sidebarAdaptable` style

### 📋 Remaining UIKit Components

#### 1. `OpenHABViewController` (OpenHABViewController.swift)
**Status**: Can be removed with refactoring

**Current Purpose**:
- Base class providing common functionality
- Certificate management delegation
- Popup message display (SwiftMessages)
- Idle timer management
- Protocol: `OpenHABViewable`

**Dependencies**: None (no longer has subclasses after WebView migration)

**Migration Path**:
- ✅ Certificate management → Move to SwiftUI environment or dedicated service
- ✅ Popup messages → Replace with SwiftUI alerts/toasts
- ✅ Idle timer → Move to app-level service
- ✅ Protocol methods → Can be replaced with SwiftUI patterns

#### 2. `OpenHABNavigationController` (OpenHABNavigationController.swift)
**Status**: Can be removed

**Current Purpose**:
- Wrapper around `UINavigationController`
- Controls status bar visibility based on preferences

**Why It Can Be Removed**:
- The app now uses SwiftUI's `NavigationStack` and `TabView`
- No longer instantiated in `AppDelegate` (replaced with `UIHostingController`)
- Status bar control can be done via SwiftUI modifiers

**Migration Path**:
- Use SwiftUI's `.statusBar(hidden:)` modifier
- Observe preferences and apply modifier at root level

## Recommended Migration Plan

### Phase 1: Extract Shared Services (Immediate)

Create SwiftUI-compatible services to replace `OpenHABViewController` functionality:

#### 1. **CertificateManagementService**
```swift
@MainActor
@Observable
class CertificateManagementService {
    static let shared = CertificateManagementService()
    
    var serverCertificateAlert: CertificateAlert?
    var clientCertificateAlert: CertificateAlert?
    
    init() {
        CertificateManagers.clientCertificateManager.delegate = self
        CertificateManagers.serverCertificateManager.delegate = self
    }
}

// Use with SwiftUI alerts
.alert(item: $certificateService.serverCertificateAlert) { alert in
    // Display alert
}
```

#### 2. **PopupMessageService**
```swift
@MainActor
@Observable
class PopupMessageService {
    static let shared = PopupMessageService()
    
    var currentMessage: PopupMessage?
    
    func show(title: String, message: String, duration: TimeInterval) {
        currentMessage = PopupMessage(title: title, message: message, duration: duration)
    }
}

// Use with SwiftUI overlays
.overlay {
    if let message = messageService.currentMessage {
        PopupMessageView(message: message)
    }
}
```

#### 3. **IdleTimerService**
```swift
@MainActor
class IdleTimerService {
    static let shared = IdleTimerService()
    
    func configure(idleOff: Bool) {
        UIApplication.shared.isIdleTimerDisabled = idleOff
    }
}
```

### Phase 2: Remove UIKit Components

#### Step 1: Remove `OpenHABNavigationController`
- Already unused in the app
- Safe to delete immediately

**Files to delete:**
- `OpenHABNavigationController.swift`

**Add to root SwiftUI view:**
```swift
OpenHABTabRootView()
    .statusBar(hidden: Preferences.shared.applicationPreferences.hideStatusBar)
```

#### Step 2: Migrate Certificate Management
- Move delegate implementations to new `CertificateManagementService`
- Use SwiftUI `.alert()` modifiers instead of UIAlertController
- Add to `OpenHABTabRootView` environment

#### Step 3: Replace Popup Messages
- Option A: Create SwiftUI toast/banner view
- Option B: Keep SwiftMessages but wrap in a SwiftUI-friendly service
- Option C: Use native SwiftUI alerts/sheets

#### Step 4: Remove `OpenHABViewController`
- After migrating all functionality to services
- Remove `OpenHABViewable` protocol

**Files to delete:**
- `OpenHABViewController.swift`

### Phase 3: Status Bar Handling

Replace `OpenHABNavigationController` status bar logic with SwiftUI:

```swift
// In OpenHABTabRootView or App root
@StateObject private var preferences = PreferencesObserver.shared

var body: some View {
    TabView {
        // ... tabs
    }
    .statusBar(hidden: preferences.applicationPreferences.hideStatusBar)
    .statusBarAnimation(.fade)
}
```

## Implementation Example

Here's how the certificate management could look in pure SwiftUI:

```swift
// CertificateManagementService.swift
@MainActor
@Observable
class CertificateManagementService {
    static let shared = CertificateManagementService()
    
    struct CertificateAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let completion: (EvaluateResult) -> Void
    }
    
    var currentAlert: CertificateAlert?
    
    private init() {
        CertificateManagers.serverCertificateManager.delegate = self
        CertificateManagers.clientCertificateManager.delegate = self
    }
}

extension CertificateManagementService: ServerCertificateManagerDelegate {
    func evaluateServerTrust(summary certificateSummary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult {
        await withCheckedContinuation { continuation in
            let title = NSLocalizedString("ssl_certificate_warning", comment: "")
            let message = String(format: NSLocalizedString("ssl_certificate_invalid", comment: ""), 
                               certificateSummary ?? "", domain ?? "")
            
            currentAlert = CertificateAlert(title: title, message: message) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    // ... other delegate methods
}

// In OpenHABTabRootView:
.alert(item: $certificateService.currentAlert) { alert in
    Alert(
        title: Text(alert.title),
        message: Text(alert.message),
        primaryButton: .default(Text("Always")) {
            alert.completion(.permitAlways)
        },
        secondaryButton: .cancel(Text("Deny")) {
            alert.completion(.deny)
        }
    )
}
```

## Benefits of Complete Migration

1. **Simplified Codebase**
   - Remove ~200 lines of UIKit boilerplate
   - No more UIKit bridging
   - Unified SwiftUI architecture

2. **Better Maintainability**
   - Single UI paradigm throughout app
   - Easier to understand and modify
   - Modern Swift patterns

3. **Future-Proof**
   - Built on Apple's latest frameworks
   - Better platform integration
   - Easier to adopt new iOS features

4. **Performance**
   - Native SwiftUI rendering
   - Reduced bridging overhead
   - Better memory management

## Testing Checklist

After migration, test:

- ✅ Server certificate warnings display correctly
- ✅ Client certificate import flow works
- ✅ Status bar shows/hides based on preferences
- ✅ Idle timer behavior is correct
- ✅ Popup messages display properly
- ✅ App lifecycle events (background/foreground) work
- ✅ Watch connectivity still functions

## Files to Delete

Once migration is complete:

1. `OpenHABViewController.swift`
2. `OpenHABNavigationController.swift`
3. `OpenHABWebViewController.swift` (already removed)

## Estimated Effort

- **Phase 1 (Services)**: 2-3 hours
- **Phase 2 (Remove UIKit)**: 1-2 hours
- **Phase 3 (Status Bar)**: 30 minutes
- **Testing**: 2-3 hours

**Total**: ~6-9 hours

## Conclusion

**Yes, we can remove both `OpenHABViewController` and `OpenHABNavigationController`!**

The migration is straightforward because:
1. No active subclasses of `OpenHABViewController` remain
2. `OpenHABNavigationController` is already unused
3. All functionality can be migrated to SwiftUI-native patterns
4. The app is already primarily SwiftUI-based

The main work involves creating service classes to handle certificate management, popup messages, and idle timer functionality in a SwiftUI-compatible way.
