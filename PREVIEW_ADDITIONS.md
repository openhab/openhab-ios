# SegmentedRowView Preview Additions

## Summary
Added comprehensive SwiftUI previews to SegmentedRowView.swift covering various use cases including wide/narrow segment texts and press-release buttons.

## Changes Made

### 1. Core Model Updates

#### OpenHABWidgetMapping.swift
- Added `releaseCommand` property to support press-release button functionality
- Updated initializer to accept optional `releaseCommand` parameter
- Updated MappingDTO conversion to pass through `releaseCommand`

#### OpenHABWidget.swift
- Added `hasPressReleaseMappings` computed property
- Returns `true` if any mapping has a non-empty `releaseCommand`
- Enables the view to distinguish between regular segments and press-release buttons

### 2. Preview Helper Function

Created `createPreviewWidget()` helper that:
- Generates OpenHABWidget instances for previews
- Accepts custom label, detail label, mappings, and selected state
- Simplifies creation of diverse preview scenarios

### 3. Preview Scenarios Added

1. **"Short Labels"** - Standard ON/OFF toggle
   - Tests basic two-segment control with short text
   - Shows selected state highlighting

2. **"Long Labels"** - Temperature control mode selector
   - Tests three longer segment labels ("Manual Override", "Calendar Based", "Fully Automatic")
   - Validates text truncation and layout with verbose labels

3. **"Multiple Segments (4)"** - Fan speed control
   - Tests four-segment control (Off, Low, Med, High)
   - Shows how multiple options are displayed

4. **"Narrow Labels (2 segments)"** - Door lock with emoji
   - Tests very short labels (🔒, 🔓)
   - Shows minimum width behavior

5. **"Press-Release Buttons"** - Blinds control
   - Tests press-release functionality with UP/DOWN buttons
   - Each mapping has a releaseCommand: "STOP"
   - Includes explanatory text

6. **"Press-Release (Multiple)"** - Garage door control
   - Tests three press-release buttons
   - Shows layout with multiple press-release options

7. **"Truncation Test"** - Long labels for both widget and detail
   - Tests layout priority and truncation behavior
   - Very long label text to verify correct truncation order

8. **"All Scenarios"** - Comprehensive overview
   - ScrollView containing all major scenarios
   - Quick visual comparison of different use cases
   - Includes short labels, long labels, press-release, and multiple segments

9. **Original Preview** - Preserved for backwards compatibility
   - Uses PreviewConstants.openHABSitemapPage
   - Maintains existing preview behavior

## Visual Coverage

### Segment Width Variations
✅ Narrow (emojis, short text)
✅ Medium (standard button text)
✅ Wide (long descriptive labels)

### Segment Count
✅ 2 segments (most common)
✅ 3 segments (multiple options)
✅ 4 segments (many options)

### Button Types
✅ Regular segmented control (momentary selection)
✅ Press-release buttons (hold and release behavior)

### Layout Scenarios
✅ With detail label
✅ Without detail label
✅ Long widget labels (truncation)
✅ Long detail labels (truncation)

## Testing

These previews can be viewed in Xcode by:
1. Opening `openHAB/SwiftUI/Rows/SegmentedRowView.swift`
2. Selecting the preview canvas
3. Choosing different preview variants from the dropdown

Each preview is self-contained and demonstrates specific functionality without requiring a running app or backend connection.
