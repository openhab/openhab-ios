# Preferences Concurrency Refactoring Summary

## Overview
This refactoring eliminates unnecessary `@MainActor` annotations from the `Preferences` actor and provides a clean `@MainActor` observable wrapper (`PreferencesObserver`) for SwiftUI views.

## Key Changes

### 1. **Removed `@MainActor` from Data Structures**
- ✅ `HomePreferences` → Now `Sendable` struct (no longer `@MainActor`)
- ✅ `ApplicationPreferences` → Now `Sendable` struct (no longer `@MainActor`)
- ✅ `TabEntry` → Was already `Sendable`

**Benefit**: These are now truly thread-safe value types that can be passed between actors without isolation concerns.

### 2. **Removed `@MainActor` from Property Wrappers**
- ✅ `@UserDefault` property wrapper
- ✅ `@UserDefaultObject` property wrapper
- ✅ `PreferencesAccess` enum methods

**Rationale**: Since `Preferences` is an actor, property access is already isolated by the actor. The `@MainActor` annotations were creating unnecessary constraints and concurrency conflicts.

**Note**: `sharedDefaults` (UserDefaults) is marked as `nonisolated(unsafe)` because `UserDefaults` is not `Sendable`, but in practice it's thread-safe for read/write operations.

### 3. **Removed `@MainActor` from Preferences Extensions**
All extension methods on `Preferences` are now properly actor-isolated:
- ✅ `listStoredHomes()` 
- ✅ `createAndLoadNewStoredSettings()`
- ✅ `renameHome()`
- ✅ `setCloudUserId()`
- ✅ `deleteStoredHome()`
- ✅ `switchActiveHome()`
- ✅ `modifyActiveHome()` - No longer requires `@MainActor` closure
- ✅ `modifyApplicationPreferences()` - No longer requires `@MainActor` closure
- ✅ `firstStoredHome()`
- ✅ `storedHome(forCloudUserId:)`
- ✅ `getNotificationConnection()`

### 4. **Updated Migration Methods**
- ✅ `migratePreferences()` → Now `async` and `nonisolated`
- ✅ `migrateToSharedDefaultsIfRequired()` → Now `async`
- ✅ `migrateToMultipleHomesIfRequired()` → Now `async`

**Benefit**: Migration can now be called from any context and properly awaits actor-isolated operations.

### 5. **Created `PreferencesObserver` for SwiftUI**

**New class**: `PreferencesObserver` - A `@MainActor` observable wrapper

```swift
@MainActor
@Observable
public final class PreferencesObserver {
    public static let shared = PreferencesObserver()
    
    public private(set) var currentHomePreferences: HomePreferences
    public private(set) var applicationPreferences: ApplicationPreferences
    
    // ... implementation
}
```

**Purpose**: 
- Provides a `@MainActor`-isolated observable object for SwiftUI views
- Automatically syncs with the `Preferences` actor
- Eliminates the need for `Task` wrappers in SwiftUI code
- Uses Combine publishers to receive updates from the actor

### 6. **Updated `SystemTab.swift`**

**Before**:
```swift
.onReceive(Preferences.shared.$currentHomePreferences) { _ in
    Task {
        updateNotificationVisibility()
    }
}

private func updateNotificationVisibility() {
    showNotifications = Preferences.shared.getNotificationConnection() != nil
        && !Preferences.shared.currentHomePreferences.demomode
}
```

**After**:
```swift
@State private var preferencesObserver = PreferencesObserver.shared

.onChange(of: preferencesObserver.currentHomePreferences) { _, _ in
    Task {
        await updateNotificationVisibility()
    }
}

private func updateNotificationVisibility() async {
    let notificationConnection = await preferencesObserver.getNotificationConnection()
    showNotifications = notificationConnection != nil
        && !preferencesObserver.currentHomePreferences.demomode
}
```

**Benefits**:
- ✅ No more awkward `onReceive` + `Task` combination
- ✅ Clear async/await pattern
- ✅ Type-safe with `@Observable` and SwiftUI's `onChange`
- ✅ Preferences operations run on actor, UI updates on main actor

## Architecture Benefits

### Before
```
┌─────────────────────┐
│  Preferences actor  │
│  with @MainActor    │ ← Forced everything onto main thread
│  property wrappers  │
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│   SwiftUI Views     │
│  with Task {}       │ ← Awkward concurrency gymnastics
└─────────────────────┘
```

### After
```
┌─────────────────────┐
│  Preferences actor  │
│  (background-safe)  │ ← Can run on any thread
└─────────────────────┘
         │
         ▼ (publishers)
┌─────────────────────┐
│ PreferencesObserver │
│   @MainActor        │ ← Clean bridge to UI
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│   SwiftUI Views     │
│   (clean code)      │ ← Simple, synchronous access
└─────────────────────┘
```

## Usage Patterns

### ✅ In SwiftUI Views
```swift
@State private var preferencesObserver = PreferencesObserver.shared

var body: some View {
    Text(preferencesObserver.currentHomePreferences.homeName)
        .onChange(of: preferencesObserver.currentHomePreferences) { _, newValue in
            // React to changes
        }
}
```

### ✅ In Background Tasks
```swift
Task {
    await Preferences.shared.modifyActiveHome { home in
        home.demomode = false
    }
}
```

### ✅ Direct Actor Access
```swift
func updateSettings() async {
    let demoMode = await Preferences.shared.currentHomePreferences.demomode
    // Use demoMode...
}
```

## Migration Guide for Other Files

If you have other files using `Preferences`, update them as follows:

### Pattern 1: SwiftUI Views observing preferences
**Before**:
```swift
.onReceive(Preferences.shared.$someProperty) { newValue in
    Task {
        // Do something
    }
}
```

**After**:
```swift
@State private var preferencesObserver = PreferencesObserver.shared

.onChange(of: preferencesObserver.currentHomePreferences) { _, newValue in
    Task {
        await updateSomething()
    }
}
```

### Pattern 2: Accessing preferences in async context
**Before**:
```swift
Task { @MainActor in
    let value = Preferences.shared.someProperty
}
```

**After**:
```swift
Task {
    let value = await Preferences.shared.someProperty
}
```

### Pattern 3: Modifying preferences
**Before**:
```swift
Task { @MainActor in
    Preferences.shared.modifyActiveHome { home in
        home.demomode = false
    }
}
```

**After**:
```swift
Task {
    await Preferences.shared.modifyActiveHome { home in
        home.demomode = false
    }
}
```

## Testing Considerations

- All preference access is now properly actor-isolated
- Tests may need to be updated to use `await` when accessing `Preferences.shared`
- `PreferencesObserver` should be tested separately for its reactive behavior
- Migration methods are now `async` and should be awaited in tests

## Potential Issues to Watch For

1. **Other files** may still have `@MainActor` requirements that conflict with the new actor-based approach
2. **Published values**: The `$currentHomePreferences` publisher still works but now bridges from actor to main actor through `PreferencesObserver`
3. **Migration calls**: Update all calls to `Preferences.migratePreferences()` to use `await`

## Next Steps

1. Search codebase for other uses of `Preferences.shared` that may need updating
2. Update any tests that access preferences
3. Consider adding more properties to `PreferencesObserver` if needed by SwiftUI views
4. Monitor for any concurrency warnings in Xcode
