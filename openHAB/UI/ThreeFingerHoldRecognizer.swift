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
// - A recognizer on the window, not on the web view, so it does not depend on the web view's own
//   recognizers or on which view is hit. (`UIApplication.sendEvent` is not an option: SwiftUI
//   installs its own application class and ignores `NSPrincipalClass`.)
// - It never takes the touches: it stays `possible` and calls `onHold` when the hold is done. The
//   page sees the touches as usual, which for fingers held still is nothing. Taking them at the
//   third finger, as an earlier version did, made the hold fail whenever a finger lifted early.
// - The order the fingers land in does not matter, and neither does one that lifts or lands
//   while the hold runs: the hold starts over with the fingers that are down. It completes when
//   three or more have been still for `holdDuration`. Land them within half a second: a finger
//   that rests longer is taken by the web view's text loupe, and the recognizer is told that
//   touch is cancelled.
// - Each finger may drift 40 pt from where it landed. Three fingers held flat on a phone are far
//   less steady than one finger in a long press (10 pt), and a stricter limit cancelled the hold
//   silently on a real device. A scroll or swipe still moves far more than that.
// - The rules are in `ThreeFingerHoldTracker`, which knows nothing about UIKit, so they can be
//   tested without touches.

/// The rules of the hold, given the touches that are down: three of them, none moving more than
/// `allowableMovement` since the hold started, until `holdElapsed()`. Generic over the touch's
/// identity so a test can use plain integers.
struct ThreeFingerHoldTracker<ID: Hashable> {
    enum Phase: Equatable {
        /// Fewer than three touches.
        case waiting
        /// Three touches are down and have not moved; the hold is running.
        case holding
        /// The hold took. Nothing happens until the fingers have lifted.
        case completed
    }

    /// What the caller does with the timer after an update.
    enum Action: Equatable {
        case none
        /// Start the hold time, over if it was running.
        case startHold
        case cancelHold
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

    /// - Parameter down: The touches on the screen now and where they are.
    mutating func update(_ down: [ID: CGPoint]) -> Action {
        let enough = down.count >= Self.requiredTouches
        switch phase {
        case .waiting:
            guard enough else { return .none }
            begin(down)
            return .startHold
        case .holding:
            guard enough else {
                phase = .waiting
                origins = [:]
                return .cancelHold
            }
            guard down.keys == origins.keys, !hasDrifted(down) else {
                begin(down)
                return .startHold
            }
            return .none
        case .completed:
            if !enough {
                phase = .waiting
                origins = [:]
            }
            return .none
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

    private mutating func begin(_ down: [ID: CGPoint]) {
        phase = .holding
        origins = down
    }

    private func hasDrifted(_ down: [ID: CGPoint]) -> Bool {
        down.contains { id, point in
            guard let origin = origins[id] else { return true }
            return hypot(point.x - origin.x, point.y - origin.y) > allowableMovement
        }
    }
}

// MARK: - SwiftUI

/// Attaches a `ThreeFingerHoldRecognizer` to the window the view is in. Use it as a background.
struct ThreeFingerHoldInstaller: UIViewRepresentable {
    @MainActor
    final class Coordinator {
        let recognizer = ThreeFingerHoldRecognizer()
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
    var progress: ThreeFingerHoldProgress
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
        context.coordinator.recognizer.onHold = onHold
        context.coordinator.recognizer.progress = progress
        context.coordinator.recognizer.isEnabled = isEnabled
    }
}

// MARK: - UIKit

/// Recognizes three fingers held still for `holdDuration`. See the decisions above.
final class ThreeFingerHoldRecognizer: UIGestureRecognizer {
    var onHold: () -> Void = {}
    var holdDuration = Duration.seconds(ThreeFingerHoldProgress.holdSeconds)
    /// Told how many fingers are down, and whether the hold is running.
    var progress: ThreeFingerHoldProgress?

    private var tracker = ThreeFingerHoldTracker<ObjectIdentifier>()
    private var down: [ObjectIdentifier: CGPoint] = [:]
    private var timer: Task<Void, Never>?

    init(holdDuration: Duration = .seconds(ThreeFingerHoldProgress.holdSeconds)) {
        self.holdDuration = holdDuration
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        track(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        track(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        release(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        release(touches)
    }

    override func reset() {
        timer?.cancel()
        timer = nil
        down = [:]
        tracker.reset()
        publish()
    }

    /// Tells the indicator what the fingers are doing.
    private func publish() {
        progress?.fingers = down.count
        progress?.isHolding = tracker.phase == .holding
    }

    private func track(_ touches: Set<UITouch>) {
        for touch in touches {
            down[ObjectIdentifier(touch)] = touch.location(in: nil)
        }
        apply(tracker.update(down))
    }

    private func release(_ touches: Set<UITouch>) {
        for touch in touches {
            down[ObjectIdentifier(touch)] = nil
        }
        apply(tracker.update(down))
    }

    private func apply(_ action: ThreeFingerHoldTracker<ObjectIdentifier>.Action) {
        switch action {
        case .none:
            break
        case .startHold:
            startTimer()
        case .cancelHold:
            timer?.cancel()
        }
        publish()
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
            publish()
            // Feedback that the hold took, while the fingers are still down.
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onHold()
        }
    }
}

extension View {
    /// Calls `action` while three fingers are held still on the screen, if `isEnabled`, and
    /// reports the fingers to `progress` meanwhile.
    func onThreeFingerHold(isEnabled: Bool, progress: ThreeFingerHoldProgress, perform action: @escaping () -> Void) -> some View {
        background(ThreeFingerHoldInstaller(isEnabled: isEnabled, progress: progress, onHold: action))
    }
}

extension ThreeFingerHoldRecognizer: UIGestureRecognizerDelegate {
    /// The page's own recognizers (scroll, pinch) may recognize while the fingers land. Unless
    /// this allows both, that excludes this one and the third finger is too late.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
