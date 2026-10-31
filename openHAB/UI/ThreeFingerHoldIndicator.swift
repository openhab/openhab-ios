// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Observation
import SwiftUI

// MARK: - What the hold is doing

//
// While the bars are hidden, nothing on the screen tells that three fingers are down, or that
// the hold has taken. This shows one dot per finger in the place of the status bar. Held with
// three, they move together into one over the hold time, which ends with the bars coming back.
//
// DECISIONS
// - Only while the bars are hidden: when they are shown there is nothing to ask for.
// - Black with a white rim, so it can be seen on a dark page as well as on a light one.
// - It cannot be touched and is out of the way of the page: a few points of height in the top
//   right corner, not the middle.
// - It sits at the very top, beside a camera cutout or the Dynamic Island where there is one, and
//   not below the top safe area, which is the page's. How far down that is follows the safe area
//   (`TopTrailingCorner`) rather than a list of devices.

/// What the hold is doing right now. Written by `ThreeFingerHoldRecognizer`, read by the indicator.
@MainActor @Observable
final class ThreeFingerHoldProgress {
    /// How long the three fingers have to be held, in seconds.
    nonisolated static let holdSeconds = 0.8

    /// How many fingers are down.
    var fingers = 0
    /// Three fingers are down and the hold time is running.
    var isHolding = false
}

/// Puts the view at the very top right of the screen, in the height of the status bar's content:
/// beside the camera cutout or the Dynamic Island, not under it, and clear of a rounded corner or
/// the hinge of the iPhone Duo, which the safe area's side inset covers.
private struct TopTrailingCorner: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            // The safe area is read by a view that ignores it, so it is still the real one.
            let top = proxy.safeAreaInsets.top
            content
                // The centre of the cutout's band; without a cutout there is no band, just the edge.
                .padding(.top, max(Self.topInset, top / 2 - ThreeFingerHoldIndicator.dotSize / 2))
                .padding(.trailing, proxy.safeAreaInsets.trailing + Self.cornerInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Between the dots and the top edge when there is no cutout band to centre them in.
    private static var topInset: CGFloat {
        8
    }

    /// Between the dots and the side edge: the display's rounded corner cuts about this much off
    /// at this height, and the dots must stay clear of it.
    private static var cornerInset: CGFloat {
        28
    }
}

/// One dot for each finger down, moving into one while the hold runs.
struct ThreeFingerHoldIndicator: View {
    static let dotSize: CGFloat = 8
    private static let dotCount = ThreeFingerHoldTracker<Int>.requiredTouches
    private static let spacing: CGFloat = 16

    let progress: ThreeFingerHoldProgress

    var body: some View {
        let count = min(progress.fingers, Self.dotCount)
        let converged = progress.isHolding
        ZStack {
            ForEach(0 ..< Self.dotCount, id: \.self) { index in
                Circle()
                    .fill(.black)
                    .overlay(Circle().stroke(.white, lineWidth: 1))
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .offset(x: converged ? 0 : (CGFloat(index) - CGFloat(count - 1) / 2) * Self.spacing)
                    .opacity(index < count ? 1 : 0)
            }
        }
        // Room for all three dots, so the others do not move when one more finger lands.
        .frame(width: Self.spacing * CGFloat(Self.dotCount - 1) + Self.dotSize, height: Self.dotSize)
        // The hold time is the time the dots take to meet; letting go spreads them again at once.
        .animation(converged ? .linear(duration: ThreeFingerHoldProgress.holdSeconds) : .easeOut(duration: 0.15), value: converged)
        .animation(.easeOut(duration: 0.15), value: count)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("ThreeFingerHoldIndicator")
        .accessibilityLabel("Fingers on the screen")
        .accessibilityValue("\(count)")
    }
}

extension View {
    /// At the very top right of the screen, where the status bar's content is. See `TopTrailingCorner`.
    func inTopTrailingCorner() -> some View {
        modifier(TopTrailingCorner())
    }
}
