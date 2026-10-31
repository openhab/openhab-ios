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

// MARK: - Three fingers held on the screen

//
// The way back to the bars while the app hides them (`BarVisibility`).
//
// DECISIONS
// - Three fingers, because nothing else on the page uses them: one finger is taps and scrolling,
//   two are pinch and map gestures, and a stationary three-finger hold matches no system gesture.
// - The recognizer takes the touches (`.began`) as soon as the third finger lands, not after the
//   hold. The page then gets `touchcancel` at once, and, since recognizers do not recognize
//   simultaneously by default, the scroll view's pan gives way. The hold itself is only a timer.
// - It is attached to the window, not the web view, so it does not depend on the web view's own
//   recognizers or on which view is hit.
// - Each finger may drift 40 pt from where it landed. Three fingers held flat on a phone are far
//   less steady than one finger in a long press (10 pt), and a stricter limit cancelled the hold
//   silently on a real device. A scroll or swipe still moves far more than that.
// - The rules (three touches, no movement, none lifted early) are in `ThreeFingerHoldTracker`,
//   which knows nothing about UIKit, so they can be tested without touches.

/// The rules of the hold: three touches down, none of them moving more than `allowableMovement`
/// and none lifting, until `holdElapsed()`. Generic over the touch's identity so a test can use
/// plain integers.
struct ThreeFingerHoldTracker<ID: Hashable> {
    enum Phase: Equatable {
        /// Fewer than three touches so far.
        case waiting
        /// Three touches are down; the hold is running.
        case holding
        case completed
        case failed
    }

    static var requiredTouches: Int {
        3
    }

    let allowableMovement: CGFloat
    private(set) var phase = Phase.waiting
    private var origins: [ID: CGPoint] = [:]

    init(allowableMovement: CGFloat = 40) {
        self.allowableMovement = allowableMovement
    }

    /// Returns true when this touch is the third, which is when the hold starts.
    @discardableResult
    mutating func touchDown(_ id: ID, at point: CGPoint) -> Bool {
        switch phase {
        case .waiting:
            origins[id] = point
            guard origins.count == Self.requiredTouches else { return false }
            phase = .holding
            return true
        case .holding:
            // A fourth finger is something else than the gesture.
            phase = .failed
            return false
        case .completed, .failed:
            return false
        }
    }

    mutating func touchMoved(_ id: ID, to point: CGPoint) {
        guard phase == .holding, let origin = origins[id] else { return }
        if hypot(point.x - origin.x, point.y - origin.y) > allowableMovement {
            phase = .failed
        }
    }

    mutating func touchUp(_ id: ID) {
        origins[id] = nil
        if phase == .holding {
            phase = .failed
        }
    }

    /// The hold time has passed. Returns true if the gesture is complete.
    mutating func holdElapsed() -> Bool {
        guard phase == .holding else { return false }
        phase = .completed
        return true
    }

    mutating func reset() {
        phase = .waiting
        origins = [:]
    }
}

// MARK: - SwiftUI

/// Attaches a `ThreeFingerHoldRecognizer` to the window the view is in. Use it as a background.
struct ThreeFingerHoldInstaller: UIViewRepresentable {
    @MainActor
    final class Coordinator: NSObject {
        var onHold: () -> Void = {}
        lazy var recognizer = ThreeFingerHoldRecognizer(target: self, action: #selector(held(_:)))

        @objc private func held(_ recognizer: ThreeFingerHoldRecognizer) {
            guard recognizer.state == .ended else { return }
            onHold()
        }
    }

    /// Moves the recognizer to the window as it is added to it, and off again when it leaves.
    final class InstallerView: UIView {
        weak var coordinator: Coordinator?
        private weak var installedIn: UIWindow?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let coordinator else { return }
            installedIn?.removeGestureRecognizer(coordinator.recognizer)
            installedIn = window
            window?.addGestureRecognizer(coordinator.recognizer)
        }
    }

    var isEnabled: Bool
    var onHold: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: InstallerView, context: Context) {
        context.coordinator.onHold = onHold
        context.coordinator.recognizer.isEnabled = isEnabled
    }
}

// MARK: - UIKit

/// Recognizes three fingers held still for `holdDuration`. See the decisions above.
final class ThreeFingerHoldRecognizer: UIGestureRecognizer {
    var holdDuration = Duration.milliseconds(800)
    private var tracker = ThreeFingerHoldTracker<ObjectIdentifier>()
    private var timer: Task<Void, Never>?

    init(target: Any?, action: Selector?, holdDuration: Duration = .milliseconds(800)) {
        self.holdDuration = holdDuration
        super.init(target: target, action: action)
        // The touches are the page's until the third finger lands.
        cancelsTouchesInView = true
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            let started = tracker.touchDown(ObjectIdentifier(touch), at: touch.location(in: nil))
            if started {
                state = .began
                startTimer()
            }
        }
        failIfTrackerFailed()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            tracker.touchMoved(ObjectIdentifier(touch), to: touch.location(in: nil))
        }
        failIfTrackerFailed()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            tracker.touchUp(ObjectIdentifier(touch))
        }
        failIfTrackerFailed()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            tracker.touchUp(ObjectIdentifier(touch))
        }
        failIfTrackerFailed()
    }

    override func reset() {
        timer?.cancel()
        timer = nil
        tracker.reset()
    }

    private func startTimer() {
        timer?.cancel()
        timer = Task { [holdDuration] in
            do {
                try await Task.sleep(for: holdDuration)
            } catch {
                return
            }
            guard tracker.holdElapsed() else { return }
            // Feedback that the hold took, while the fingers are still down.
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            state = .ended
        }
    }

    /// After `.began` a recognizer ends or is cancelled, it does not fail.
    private func failIfTrackerFailed() {
        guard tracker.phase == .failed else { return }
        timer?.cancel()
        switch state {
        case .began, .changed:
            state = .cancelled
        case .possible:
            state = .failed
        default:
            break
        }
    }
}
