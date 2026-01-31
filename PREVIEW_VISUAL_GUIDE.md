# SegmentedRowView Preview Visual Guide

## Preview Descriptions

This document describes what each preview scenario looks like and tests.

### 1. Preview: "Short Labels"

**Purpose:** Tests basic two-segment control with short text labels

**Visual Layout:**
```
[🔲 Icon] Light Switch          Status    [ON | OFF]
                                           ^^^ selected
```

**Key Features:**
- Standard ON/OFF toggle
- Short, clear labels
- Shows selected state highlighting (ON is highlighted)
- Detail label "Status" displayed
- Tests minimum viable segmented control

---

### 2. Preview: "Long Labels"

**Purpose:** Tests three longer segment labels and text truncation

**Visual Layout:**
```
[🔲 Icon] Temperature Control Mode   Current Mode   [Manual... | Calendar... | Fully...]
                                                                               ^^^^^^^^^^^^ selected
```

**Key Features:**
- Three segments with verbose labels
- Labels truncate appropriately: "Manual Override" → "Manual...", etc.
- Shows how layout handles longer text
- Current selection: "Fully Automatic"
- Tests maxWidth constraint (120pt) on segments

---

### 3. Preview: "Multiple Segments (4)"

**Purpose:** Tests four-segment control layout

**Visual Layout:**
```
[🔲 Icon] Fan Speed          Level 3    [Off | Low | Med | High]
                                                        ^^^^ selected
```

**Key Features:**
- Four evenly-spaced segments
- Short labels fit comfortably
- Selection indicator shows "High" (index 3)
- Tests how segmented control divides space equally
- Shows practical use case (fan speed control)

---

### 4. Preview: "Narrow Labels (2 segments)"

**Purpose:** Tests very short labels (emojis)

**Visual Layout:**
```
[🔲 Icon] Door Lock    [🔒 | 🔓]
                        ^^ selected
```

**Key Features:**
- Emoji-only labels (lock/unlock)
- Tests minimum width constraint (75pt minimum for control)
- Shows that segments can be very compact
- No detail label
- Tests icon-based segment labels

---

### 5. Preview: "Press-Release Buttons"

**Purpose:** Tests press-release functionality with hold behavior

**Visual Layout:**
```
[🔲 Icon] Blinds Control          Position    [  Up  ][  Down  ]
                                               ^^^^^^^^  ^^^^^^^^
                                               (separate buttons, not segmented)

"Press and hold buttons to move blinds"
```

**Key Features:**
- Two separate press-release buttons (not a segmented control)
- Each button has rounded corners independently
- Visual difference from segmented control
- Each mapping has `releaseCommand: "STOP"`
- Demonstrates hold-to-action, release-to-stop pattern
- Includes explanatory caption

---

### 6. Preview: "Press-Release (Multiple)"

**Purpose:** Tests three press-release buttons layout

**Visual Layout:**
```
[🔲 Icon] Garage Door    [  Open  ][  Close  ][  Partial  ]
                         ^^^^^^^^^  ^^^^^^^^^   ^^^^^^^^^^^
                         (three separate buttons)

"Hold to perform action, release to stop"
```

**Key Features:**
- Three independent press-release buttons
- Each with releaseCommand: "STOP"
- Shows how multiple press-release buttons lay out horizontally
- Tests spacing between multiple buttons
- Includes usage instruction caption

---

### 7. Preview: "Truncation Test"

**Purpose:** Validates label truncation behavior and layout priorities

**Visual Layout:**
```
[🔲 Icon] Very Long Label That Should Tr...   Also A Very Long Det...   [First | Second]
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^^^^^^^^^^^^^^^
          (truncates second, layoutPriority: 1)  (truncates first, layoutPriority: 0)
```

**Key Features:**
- Very long widget label: "Very Long Label That Should Truncate Nicely"
- Very long detail label: "Also A Very Long Detail Text Here"
- Tests truncation order:
  1. Detail label truncates first (layoutPriority: 0)
  2. Spacer compresses to minLength: 8
  3. Widget label truncates second (layoutPriority: 1)
  4. Segments maintain minWidth: 75pt
- Includes explanatory caption: "Tests label truncation behavior"

---

### 8. Preview: "All Scenarios"

**Purpose:** Comprehensive overview in a scrollable view

**Visual Layout:**
```
┌─────────────────────────────────────────────────┐
│ [🔲] Light              [ON | OFF]              │ ← Short labels
├─────────────────────────────────────────────────┤
│ [🔲] Climate Mode  Auto [Man | Auto | Sch]      │ ← Long labels (3)
├─────────────────────────────────────────────────┤
│ [🔲] Shutter         [↑][↓]                     │ ← Press-release
├─────────────────────────────────────────────────┤
│ [🔲] Speed           [Off | Low | Mid | High]   │ ← Multiple (4)
└─────────────────────────────────────────────────┘
```

**Key Features:**
- ScrollView containing multiple scenarios
- Quick side-by-side comparison
- Dividers between each scenario
- Mix of all major use cases:
  - Short labels
  - Long labels with 3 segments
  - Press-release buttons
  - Multiple segments (4)
- Useful for regression testing

---

### 9. Preview: Original (Unnamed)

**Purpose:** Backwards compatibility with existing preview

**Visual Layout:**
```
[🔲 Icon] Fernsteuerung    [Overwrite | Kalender | Automatik]
                                                   ^^^^^^^^^^^ selected (state: "2")
```

**Key Features:**
- Uses PreviewConstants.openHABSitemapPage!.widgets[4]
- Real data from test sitemap
- Three German-language segments
- Maintains existing preview behavior
- Ensures no breaking changes

---

## Layout Mechanics Tested

### Spacing Constraints
- ✅ Icon → Text: Default spacing
- ✅ Text → Detail: Minimum 8pt (Spacer minLength: 8)
- ✅ Detail → Segments: 8pt (.padding(.leading, 8))
- ✅ Segments → Edge: 20pt (.padding(.trailing, 20))

### Width Constraints
- ✅ Segment minimum: 75pt (.frame(minWidth: 75))
- ✅ Segment maximum per button: 120pt (.frame(maxWidth: 120))
- ✅ Icon: 32×32 fixed

### Truncation Priority
- ✅ Detail label: Priority 0 (truncates first)
- ✅ Widget label: Priority 1 (truncates second)
- ✅ Segments: Protected (maintain minimum width)

### Button Types
- ✅ Regular segmented control: Animated selection indicator
- ✅ Press-release buttons: Independent rounded buttons with gesture handling

---

## How to View Previews in Xcode

1. Open `openHAB.xcworkspace` in Xcode
2. Navigate to `openHAB/SwiftUI/Rows/SegmentedRowView.swift`
3. Enable Canvas (Editor → Canvas or Cmd+Option+Enter)
4. Click the preview selector dropdown (top of canvas)
5. Choose any of the 9 named previews to view

Each preview is fully self-contained and will render without requiring:
- A running app
- Backend connection
- Simulator
- Real device

This makes them perfect for quick UI verification during development.

---

### 10. Preview: "Button Types Comparison" (NEW)

**Purpose:** Clearly demonstrates the difference between regular segmented controls and press-release buttons

**Visual Layout:**
```
╔═══════════════════════════════════════════════════════════╗
║     Segmented Control vs Press-Release Buttons           ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  Regular Segmented Control                               ║
║  Tap to select, animated indicator shows selection       ║
║  ┌───────────────────────────────────────────────┐       ║
║  │ [🔲] Light Mode  Auto  [Manual|Auto|Schedule] │       ║
║  │                             ^^^^               │       ║
║  └───────────────────────────────────────────────┘       ║
║                                                           ║
║  ─────────────────────────────────────────────────       ║
║                                                           ║
║  Press-Release Buttons                                   ║
║  Hold to activate, release to stop                       ║
║  ┌───────────────────────────────────────────────┐       ║
║  │ [🔲] Blinds  Control  [↑][↓]                  │       ║
║  │                       ^^^  ^^^                 │       ║
║  └───────────────────────────────────────────────┘       ║
║                                                           ║
║  Key Differences                                         ║
║  ┌───────────────────────────────────────────────┐       ║
║  │ 👆 Segmented Control                          │       ║
║  │ • Single tap to select                        │       ║
║  │ • Animated selection indicator                │       ║
║  │ • Stays selected until changed                │       ║
║  │ • No releaseCommand                           │       ║
║  │                                                │       ║
║  │ ☝️ Press-Release Buttons                      │       ║
║  │ • Hold down to activate                       │       ║
║  │ • Independent rounded buttons                 │       ║
║  │ • Sends command on press                      │       ║
║  │ • Sends releaseCommand on release             │       ║
║  └───────────────────────────────────────────────┘       ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

**Key Features:**
- Side-by-side comparison of both button types
- Real working examples of each type
- Clear visual distinction between the two
- Detailed explanation of differences
- Demonstrates that press-release buttons ARE implemented
- Shows exactly when each type is used:
  - Regular: When mappings have NO releaseCommand
  - Press-Release: When mappings HAVE releaseCommand

**Use Case:**
Perfect for understanding the architecture and seeing how the `hasPressReleaseMappings` logic determines which button type to render.

---

## Summary of Press-Release Button Previews

We now have **4 previews** that demonstrate press-release button functionality:

| Preview | Line | Press-Release | Description |
|---------|------|---------------|-------------|
| "Press-Release Buttons" | 287 | ✅ Yes (2 buttons) | Blinds Up/Down control |
| "Press-Release (Multiple)" | 307 | ✅ Yes (3 buttons) | Garage door control |
| "All Scenarios" | 348 | ✅ Yes (included) | Shutter Up/Down in ScrollView |
| "Button Types Comparison" | 407 | ✅ Yes (with regular) | Side-by-side comparison |

### Detection Logic

All press-release previews work because:

1. Mappings are created with `releaseCommand`:
   ```swift
   OpenHABWidgetMapping(command: "UP", label: "↑", releaseCommand: "STOP")
   ```

2. Widget's `hasPressReleaseMappings` checks:
   ```swift
   mappingsOrItemOptions.contains { $0.releaseCommand != nil && !$0.releaseCommand!.isEmpty }
   ```

3. View renders appropriate component:
   ```swift
   if widget.hasPressReleaseMappings {
       pressReleaseButtons  // Renders press-release style
   } else {
       segmentedButtons     // Renders segmented control style
   }
   ```

### Visual Differences

**Regular Segmented Control:**
- Single rounded rectangle background
- Animated selection indicator (lighter rectangle)
- Segments divided by spacing, appearing connected
- Tap to select, stays selected

**Press-Release Buttons:**
- Independent rounded rectangles for each button
- No selection indicator (stateless)
- Clear spacing between buttons
- Hold to activate, release to stop

---

## Updated Preview Count

Total Previews: **10**
- Regular Segmented Controls: 6
- Press-Release Buttons: 4 (including comparison)

All press-release previews are fully functional and correctly trigger the press-release button rendering path.
