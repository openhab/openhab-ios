# SwiftUI phased animations: opacity, layout, and sequencing

Guidance for animating opacity and layout in sequence in SwiftUI, including what reliably works and what silently fails.

---

## Opacity animations — what works and what doesn't

### What reliably works: `.transition(.opacity)` on conditional views

```swift
if !hidden {
    MyView()
        .transition(.opacity)
}
// driven by:
withAnimation(.easeInOut(duration: 0.2)) { hidden = true }
```

This is the only opacity approach confirmed to produce a real interpolated fade. Verified across iOS 26 (GlassEffectContainer) and standard `.background(.regularMaterial)` containers.

### What silently fails (snaps instead of fading)

- `withAnimation { doubleVar = 0.0 }` + `.opacity(doubleVar)` — snaps to final value
- View-level `.animation(.easeInOut, value: doubleVar)` + plain assignment — snaps
- `Bool ? 0 : 1` ternary driven by `withAnimation` — correct timing but no interpolation
- Custom `ViewModifier` with explicit `Animatable.animatableData` — snaps inside composited containers (e.g. iOS 26 Glass)

### The `.animation(nil, value:)` trap

Adding `.animation(nil, value: stateVar)` as a cancel guard on a view that also has `.animation(otherAnim, value: otherVar)` will kill the animation it was meant to protect. When two `.animation(_:value:)` modifiers on the **same view** fire in the same render pass, the outermost one wins — even if it is `nil`.

---

## Sequencing opacity and layout changes (two-phase animation)

Goal: fade a view out first, then collapse its layout space (or vice versa).

### The pattern

```swift
// State
@State private var detailsHidden = false   // drives phase-1 opacity
@State private var layoutCollapsed = false // drives phase-2 layout

private func collapse() {
    let half = 0.125  // half of total duration
    // Phase 1: fade out
    withAnimation(.easeInOut(duration: half)) { detailsHidden = true }
    // Phase 2: collapse layout (delayed so it starts after the fade completes)
    withAnimation(.easeInOut(duration: half).delay(half)) { layoutCollapsed = true }
}

private func expand() {
    let half = 0.125
    // Phase 1: expand layout
    withAnimation(.easeInOut(duration: half)) { layoutCollapsed = false }
    // Phase 2: fade in (delayed so content appears after space is ready)
    withAnimation(.easeInOut(duration: half).delay(half)) { detailsHidden = false }
}
```

### Preserving layout space during the fade (phase 1)

When a conditional view is removed its space collapses immediately after the transition animation completes. Without a placeholder, the phase-2 layout animation has nothing to animate from.

```swift
ZStack(alignment: .topLeading) {
    MyView().hidden()          // always present — holds the space during the fade
    if !detailsHidden {
        MyView()
            .transition(.opacity)
    }
}
.frame(maxHeight: layoutCollapsed ? 0 : naturalHeight, alignment: .top)
.clipped()
```

The `.hidden()` copy maintains the layout footprint through phase 1. The outer `.frame(maxHeight:)` then has a real height to animate away in phase 2.

---

## Using separate state variables to avoid animation override

A parent container with `.animation(sectionAnim, value: mainVar)` broadcasts that animation to all subtree changes triggered by `mainVar`. If you trigger a transition with the same variable, that broadcast overrides your timing.

Use a **separate** state variable for each independent animation phase:

```swift
// BAD: condition and outer animation share the same variable
VStack { ... }
    .animation(sectionAnim, value: isExpanded)  // broadcasts when isExpanded changes

if !isExpanded {               // same variable — broadcast overrides this transition
    DetailView().transition(.opacity)
}

// GOOD: separate variables
VStack { ... }
    .animation(sectionAnim, value: isExpanded)  // only affects isExpanded-driven changes

if !detailsHidden {            // different variable — gets its own withAnimation context
    DetailView().transition(.opacity)
}
// driven by:
withAnimation(.easeInOut(duration: half)) { detailsHidden = true }
```

Multiple `withAnimation` calls in the same synchronous block each create independent transactions for their respective state changes. Delays are preserved per-variable: `withAnimation(.easeInOut.delay(0.125)) { layoutCollapsed = true }` correctly delays that animation even when other `withAnimation` calls fire in the same block.

---

## Verified in this codebase

`openHAB/UI/ToolbarMenu.swift` — `homeHeader()` two-phase animation of ConnectionView and gear button, iOS 26, physical device.
