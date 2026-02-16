# Complete UIKit Removal - Implementation Guide

## Overview

This guide shows how to complete the migration from UIKit to pure SwiftUI by removing `OpenHABViewController` and `OpenHABNavigationController`.

## What's Been Created

### 1. **CertificateManagementService.swift** ✅
A complete SwiftUI-native service that handles all certificate management:
- Server certificate trust evaluation
- Client certificate import
- Password prompts for PKCS#12
- Error alerts
- SwiftUI alert modifiers

### 2. **IdleTimerService.swift** ✅
A service that manages the device idle timer:
- Observes user preferences
- Handles app lifecycle events
- Provides SwiftUI view modifier

## Implementation Steps

### Step 1: Update OpenHABTabRootView

Add the certificate management alerts and idle timer management to your root view:

```swift
// In OpenHABTabRootView.swift

var body: some View {
    TabView(selection: tabSelectionBinding) {
        // ... existing tab content
    }
    .tabViewStyle(.sidebarAdaptable)
    .tabBarMinimizeBehavior(.onScrollDown)
    .environmentObject(networkTracker)
    // ADD THESE MODIFIERS:
    .certificateManagementAlerts()  // Handles all certificate alerts
    .idleTimerManagement()          // Manages idle timer
    .statusBar(hidden: Preferences.shared.applicationPreferences.hideStatusBar) // Replace navigation controller status bar logic
    // ... rest of your modifiers
}
```

### Step 2: Remove Old Files

Once Step 1 is complete and tested, safely delete:

1. **OpenHABViewController.swift**
   - All functionality now in services
   - No subclasses remain after WebView migration

2. **OpenHABNavigationController.swift**
   - Already unused in AppDelegate
   - Status bar control moved to SwiftUI modifier

3. **OpenHABWebViewController.swift** 
   - Already removed in WebView migration

### Step 3: Update Any Remaining References

Search your project for any lingering references:

```bash
# Search for OpenHABViewController references
grep -r "OpenHABViewController" .

# Search for OpenHABNavigationController references  
grep -r "OpenHABNavigationController" .

# Search for OpenHABViewable protocol
grep -r "OpenHABViewable" .
```

Remove or update any found references.

## Testing Checklist

After implementation, verify:

### Certificate Management
- [ ] Server certificate warnings appear correctly
- [ ] Can choose "Always", "Once", or "Deny" for server certificates
- [ ] Certificate mismatch warnings display properly
- [ ] Client certificate import prompt works
- [ ] Password prompt for PKCS#12 certificates works
- [ ] Certificate import errors display correctly

### Idle Timer
- [ ] Screen stays awake when preference is enabled
- [ ] Screen sleeps normally when preference is disabled
- [ ] Idle timer disables when app enters background
- [ ] Idle timer re-enables based on preference when app becomes active

### Status Bar
- [ ] Status bar hides when preference is enabled
- [ ] Status bar shows when preference is disabled
- [ ] Status bar animates smoothly

### General
- [ ] App launches successfully
- [ ] All tabs work correctly
- [ ] Navigation works as expected
- [ ] No crashes or memory leaks

## Code Changes Summary

### Before (UIKit-based):
```swift
// OpenHABViewController.swift - ~200 lines
class OpenHABViewController: UIViewController, OpenHABViewable {
    func reloadView() {}
    func showPopupMessage(...) {}
    func evaluateServerTrust(...) async -> Result {}
    func askForClientCertificateImport(...) async -> Bool {}
    // etc...
}

// OpenHABNavigationController.swift - ~40 lines  
class OpenHABNavigationController: UINavigationController {
    override var prefersStatusBarHidden: Bool { ... }
}
```

### After (SwiftUI-based):
```swift
// CertificateManagementService.swift
@Observable class CertificateManagementService {
    var serverCertificateAlert: ServerCertificateAlert?
    // Handles all certificate interactions via SwiftUI alerts
}

// IdleTimerService.swift
class IdleTimerService {
    func configure(idleOff: Bool)
    // Manages idle timer lifecycle
}

// In OpenHABTabRootView
.certificateManagementAlerts()
.idleTimerManagement()
.statusBar(hidden: ...)
```

## Benefits

1. **Simpler Architecture**
   - No UIViewController inheritance hierarchy
   - Direct SwiftUI patterns
   - Clear separation of concerns

2. **Less Code**
   - ~240 lines of UIKit code removed
   - ~200 lines of SwiftUI service code added
   - Net reduction in complexity

3. **Better Testability**
   - Services are isolated and testable
   - No UIViewController dependencies
   - Observable state for easy mocking

4. **Modern Swift**
   - Swift Concurrency throughout
   - @Observable macro
   - SwiftUI-native patterns

5. **Future-Proof**
   - Pure SwiftUI app
   - Easier to adopt new features
   - Better performance

## Troubleshooting

### Issue: Certificate alerts not showing
**Solution**: Ensure `.certificateManagementAlerts()` is added to your root view

### Issue: Idle timer not working
**Solution**: Verify `.idleTimerManagement()` is in your view hierarchy and preferences are set correctly

### Issue: Status bar not hiding
**Solution**: Check that `.statusBar(hidden:)` modifier is present and preference value is correct

### Issue: Crash on certificate operation
**Solution**: Verify `CertificateManagementService.shared` is initialized early (it auto-initializes on first access)

## Migration Rollback Plan

If issues arise, you can temporarily revert:

1. Keep the old UIKit files in the project
2. Comment out the new service modifiers
3. Re-enable old code paths
4. Debug and fix issues
5. Re-apply migration

However, with the provided services and testing checklist, this shouldn't be necessary.

## Additional Notes

### SwiftMessages Integration
The old `showPopupMessage` method used SwiftMessages for temporary notifications. If you still need this functionality:

**Option 1**: Create a SwiftUI toast view
**Option 2**: Use native SwiftUI alerts/sheets  
**Option 3**: Keep SwiftMessages and wrap it in a service (similar to certificate service)

### Navigation Bar Hiding
The WebView handles its own navigation bar hiding via the `hideNavigationBar` property. This is managed in `OpenHABWebView` and doesn't conflict with the root status bar setting.

## Next Steps

1. Implement Step 1 (add modifiers to OpenHABTabRootView)
2. Test thoroughly using the checklist
3. Execute Step 2 (delete old files)
4. Search for and clean up any remaining references (Step 3)
5. Celebrate having a pure SwiftUI app! 🎉

## Questions?

If you encounter any issues during migration:
1. Check the testing checklist
2. Review the troubleshooting section
3. Verify all code changes were applied correctly
4. Check console logs for any errors

---

**Estimated Time**: 1-2 hours for implementation + 2-3 hours for testing = 3-5 hours total
