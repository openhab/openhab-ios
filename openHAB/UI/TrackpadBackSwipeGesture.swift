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

import SwiftUI
import UIKit

/// A trackpad-only "swipe between pages" back gesture, matching the two-finger swipe
/// convention Safari and Mail use for back navigation with a trackpad or Magic Mouse.
///
/// `allowedScrollTypesMask = .discrete` routes this recognizer to the discrete swipe
/// events a trackpad/mouse sends for page navigation, as distinct from `.continuous`
/// scroll events, so it doesn't compete with normal two-finger content scrolling (which
/// stays continuous and goes to the web view's own scroll view). It never fires from
/// on-screen touch, since touch input isn't a scroll type at all.
struct TrackpadBackSwipeGesture: UIGestureRecognizerRepresentable {
    /// Minimum horizontal translation, in points, before a swipe counts as "back".
    private static let threshold: CGFloat = 60

    let action: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.allowedScrollTypesMask = .discrete
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard recognizer.state == .ended else { return }
        let translation = recognizer.translation(in: recognizer.view)
        guard translation.x > Self.threshold, translation.x > abs(translation.y) else { return }
        action()
    }
}
