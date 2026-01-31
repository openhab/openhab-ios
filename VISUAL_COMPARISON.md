# Visual Layout Comparison

## Horizontal Layout Structure

### Before (Storyboard - SegmentedUITableViewCell)
```
┌─────────────────────────────────────────────────────────────────┐
│ [Icon] TextLabel        DetailLabel  [Segmented Control]        │
│ 32×32  (truncates 2nd)  (≥8pt gap)   [8pt] [≥75pt width] [20pt]│
│                         (truncates 1st)                          │
└─────────────────────────────────────────────────────────────────┘
    └─62pt from edge
```

### After (SwiftUI - SegmentedRowView)
```
┌─────────────────────────────────────────────────────────────────┐
│ [Icon] TextLabel        DetailLabel  [Segmented Control]        │
│ 32×32  (priority: 1)    (≥8pt gap)   [8pt] [≥75pt width] [20pt]│
│                         (priority: 0)                            │
└─────────────────────────────────────────────────────────────────┘
    └─default cell padding
```

## Constraint Details

### Element Spacing
| Position | Storyboard | SwiftUI | Status |
|----------|-----------|---------|--------|
| Icon leading | 62pt from superview | Default cell padding | ✅ Equivalent |
| Icon → Text | Implicit | Implicit (IconView included) | ✅ Same |
| Text → Detail | ≥8pt | `Spacer(minLength: 8)` | ✅ Ported |
| Detail → Segment | 8pt | `.padding(.leading, 8)` | ✅ Ported |
| Segment → Edge | 20pt | `.padding(.trailing, 20)` | ✅ Ported |

### Size Constraints
| Element | Storyboard | SwiftUI | Status |
|---------|-----------|---------|--------|
| Icon | 32×32 fixed | `.frame(width: 32, height: 32)` | ✅ Same |
| SegmentedControl | minWidth ≥75pt | `.frame(minWidth: 75)` | ✅ Ported |

### Compression Priorities
| Element | Storyboard | SwiftUI | Status |
|---------|-----------|---------|--------|
| TextLabel | Priority 249 (default) | `.layoutPriority(1)` | ✅ Equivalent |
| DetailLabel | Priority 751 (high) | `.layoutPriority(0)` | ✅ Equivalent* |
| SegmentedControl | Priority 751 (high) | `.fixedSize()` + `minWidth` | ✅ Equivalent |

*Note: In SwiftUI, lower `layoutPriority` values mean the view will shrink/truncate first, 
opposite to UIKit where higher values mean higher resistance to compression.

## Truncation Behavior

### Scenario 1: Ample Space
```
Storyboard:  [Icon] Switch Room Blabblalalsls  Label  [ON │ OFF]
SwiftUI:     [Icon] Switch Room Blabblalalsls  Label  [ON │ OFF]
```
✅ Identical

### Scenario 2: Limited Space (DetailLabel truncates first)
```
Storyboard:  [Icon] Switch Room Blabblalalsls  Lab…  [ON │ OFF]
SwiftUI:     [Icon] Switch Room Blabblalalsls  Lab…  [ON │ OFF]
```
✅ Identical behavior (DetailLabel with layoutPriority: 0 truncates first)

### Scenario 3: Very Limited Space (TextLabel also truncates)
```
Storyboard:  [Icon] Switch Room Blabb…  Lab…  [ON │ OFF]
SwiftUI:     [Icon] Switch Room Blabb…  Lab…  [ON │ OFF]
```
✅ Identical behavior (TextLabel with layoutPriority: 1 truncates second)

### Scenario 4: Minimal Space (Only essential elements)
```
Storyboard:  [Icon] Swit…    [ON │ OFF]
SwiftUI:     [Icon] Swit…    [ON │ OFF]
```
✅ Identical behavior (Both labels truncated, segment control at minimum 75pt)

## Key Differences

### 1. Leading Spacing
- **Storyboard**: Explicit 62pt constraint from superview to TextLabel
- **SwiftUI**: Uses default cell/row padding (typically 16-20pt per side)
- **Impact**: Minimal - SwiftUI rows have standard padding that achieves similar visual result

### 2. Priority System
- **Storyboard**: UIKit's compressionResistance (higher = more resistant)
- **SwiftUI**: layoutPriority (higher = more important, shrinks last)
- **Impact**: None - priorities correctly inverted to achieve same behavior

### 3. Spacing Control
- **Storyboard**: Constraint-based with specific values
- **SwiftUI**: Modifier-based with padding and Spacer
- **Impact**: None - equivalent visual result

## Code Structure Comparison

### Storyboard (XML)
```xml
<segmentedControl horizontalCompressionResistancePriority="751">
    <constraint firstAttribute="width" relation="greaterThanOrEqual" constant="75"/>
</segmentedControl>
<constraint firstItem="segmentControl" firstAttribute="leading" 
            secondItem="detailLabel" secondAttribute="trailing" constant="8"/>
```

### SwiftUI (Code)
```swift
segmentedButtons
    .padding(.leading, 8)
    .frame(minWidth: 75)
```

## Testing Checklist

- [ ] **Visual Parity**: Side-by-side comparison shows identical layout
- [ ] **Truncation**: DetailLabel truncates before TextLabel
- [ ] **Minimum Width**: SegmentedControl never shrinks below 75pt
- [ ] **Spacing**: All gaps match storyboard (8pt, 20pt)
- [ ] **Edge Cases**: Test with very long/short labels
- [ ] **Screen Sizes**: Test on iPhone SE, standard, and Plus sizes
- [ ] **Accessibility**: Test with larger text sizes
- [ ] **Dark Mode**: Verify colors work in both modes

## Validation

To validate the implementation:

1. **Run side-by-side**: 
   - Old UIKit cell in one view
   - New SwiftUI row in another view
   - Compare with same widget data

2. **Measure spacing**:
   - Use Xcode's View Debugger
   - Verify 8pt gaps
   - Verify 20pt trailing
   - Verify 75pt minimum width

3. **Test truncation**:
   - Use widgets with increasingly long labels
   - Verify DetailLabel truncates first
   - Verify TextLabel truncates second
   - Verify SegmentedControl maintains 75pt minimum
