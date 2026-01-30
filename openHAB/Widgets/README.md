# SwiftUI Widget Implementations

This directory contains SwiftUI implementations of openHAB widgets that can be used for future SwiftUI migration.

## SegmentedControlWidget

SwiftUI implementation of segmented control for switch widgets with mappings.

### Features

- **Repeated Click Support**: Unlike the standard UISegmentedControl, this implementation allows clicking the same button multiple times to resend commands, matching the behavior of the Android app and BasicUI (addresses issue #530)
- **Visual Selection**: Shows which option is currently selected with highlighted background
- **Debouncing**: Includes 300ms debounce to prevent accidental double-taps
- **Clean Design**: Uses native SwiftUI components with proper iOS styling

### Usage

```swift
SegmentedControlWidget(widget: openHABWidget)
```

### Implementation Details

The key difference from UIKit's `UISegmentedControl` is that SwiftUI allows us to use individual `Button` views, which:
1. Always respond to taps, even when already selected
2. Can show visual selection state independently
3. Support custom styling and layout

This approach provides the best of both worlds:
- Visual feedback of current selection (like non-momentary UISegmentedControl)
- Ability to repeatedly click the same option (like momentary UISegmentedControl)

### Comparison with UIKit Implementation

| Aspect | UIKit (momentary) | UIKit (non-momentary) | SwiftUI |
|--------|-------------------|----------------------|---------|
| Repeated clicks | ✅ Yes | ❌ No | ✅ Yes |
| Visual selection | ❌ No | ✅ Yes | ✅ Yes |
| Debouncing | ❌ No | ❌ No | ✅ Yes |

### Android App Behavior

The Android app implementation (as noted in issue #530) always sends commands when a button is pressed, even if it's the same state as before. This SwiftUI implementation matches that behavior while providing better UX through visual feedback and debouncing.
