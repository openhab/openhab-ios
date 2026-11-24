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

import Foundation

/// Turns slider gestures into at most one live update per distinct value and one release command.
///
/// A SwiftUI `Slider` created with `step:` can, since iOS 26, skip the opening editing callback,
/// report `editing == false` on every frame of the thumb-shrink animation, and then report a late
/// `editing == true` that never closes. Those callbacks were sending a burst of the previous value
/// a few hundred milliseconds after the finger lifted. Finger contact is the source of truth.
/// Value changes are accepted while the finger is down. An editing callback is not a release
/// until the finger is up, and slider callbacks stay ignored for a short quiet period after that.
struct SliderDragCoordinator: Equatable {
    enum Action: Equatable {
        case change(Double)
        case release(Double)
    }

    /// How long after a release to ignore slider callbacks that are not a new touch.
    /// The stale burst arrives about 0.3–0.5 s after the finger lifts.
    static let postReleaseQuietInterval: TimeInterval = 0.6

    /// A drag-gesture end can be reported while the finger is still down, because a live
    /// update refreshes the row. Wait this long, and keep the drag if the thumb keeps moving.
    static let liftConfirmationDelay: TimeInterval = 0.15

    private(set) var isDragging = false
    private(set) var dragValue: Double?
    private(set) var fingerIsDown = false
    private(set) var pendingLift = false

    private var suppressed = false
    private var releaseSent = false
    private var moved = false
    private var startValue: Double?
    private var lastChangeValue: Double?
    private var quietUntil: Date?
    private var releasedValue: Double?
    private var staleBurstValue: Double?
    private var ignoreStaleUntil: Date?

    mutating func fingerChanged(displayedValue: Double) -> [Action] {
        let isNewTouch = !fingerIsDown
        fingerIsDown = true
        if pendingLift {
            // The recognizer restarted during a drag. The finger never left.
            pendingLift = false
            return []
        }
        guard isNewTouch else { return [] }
        if isDragging || dragValue != nil {
            return []
        }

        suppressed = false
        quietUntil = nil
        releaseSent = false
        moved = false
        startValue = displayedValue
        lastChangeValue = nil
        dragValue = nil
        isDragging = false
        releasedValue = nil
        staleBurstValue = nil
        ignoreStaleUntil = nil
        // Wait for the value to change. Touch-down alone is also how a scroll starts.
        return []
    }

    mutating func fingerEnded(displayedValue: Double, now: Date) -> [Action] {
        guard beginLift(now: now) else { return [] }
        pendingLift = false
        return finish(displayedValue: displayedValue, now: now)
    }

    /// Same end signal as ``fingerEnded(_:now:)``, but the release waits for
    /// ``commitPendingLift(displayedValue:now:)``. A value change in between means
    /// the finger is still down and the gesture end was caused by a view update.
    mutating func fingerMayHaveLifted(now: Date) -> Bool {
        beginLift(now: now)
    }

    mutating func commitPendingLift(displayedValue: Double, now: Date) -> [Action] {
        guard pendingLift, !fingerIsDown else { return [] }
        pendingLift = false
        return finish(displayedValue: displayedValue, now: now)
    }

    mutating func editingChanged(_ editing: Bool, displayedValue: Double, now: Date) -> [Action] {
        if blocksSliderCallback(now: now) {
            return []
        }

        if editing {
            guard !suppressed, !pendingLift else { return [] }
            return begin(displayedValue: displayedValue)
        }

        // An unbalanced false while the finger is still down is not a release.
        // A lift that is waiting for confirmation is finished by commitPendingLift.
        guard !pendingLift, !fingerIsDown, !suppressed else { return [] }
        return finish(displayedValue: displayedValue, now: now)
    }

    mutating func valueChanged(_ newValue: Double, displayedValue: Double, step: Double, now: Date) -> [Action] {
        guard !suppressed else { return [] }
        if isStaleJump(newValue, step: step, now: now) {
            return []
        }

        if pendingLift {
            let anchor = dragValue ?? displayedValue
            // A refresh can echo the current thumb value. That is not movement.
            if approximately(newValue, anchor, step: step) {
                return []
            }
            pendingLift = false
            fingerIsDown = true
        }

        if !fingerIsDown, isQuiet(now: now) {
            // The release animation moves the thumb after the finger is gone.
            // Treating that as a new drag leaves the finger marked down, and
            // every later release is then cancelled.
            return []
        }
        if blocksSliderCallback(now: now) {
            return []
        }

        if !isDragging {
            // Stepped sliders can move the thumb without ever reporting editing=true.
            // An echo of the value already on screen is not a drag.
            guard !approximately(newValue, displayedValue, step: step) else { return [] }
            _ = begin(displayedValue: displayedValue)
        }

        dragValue = newValue
        if !approximately(newValue, startValue, step: step) {
            moved = true
        }
        guard !approximately(newValue, lastChangeValue, step: step) else { return [] }
        lastChangeValue = newValue
        return [.change(newValue)]
    }

    /// Drops the in-flight drag without sending. Used when the server value diverges mid-drag.
    mutating func cancel(now: Date) {
        suppressed = fingerIsDown
        isDragging = false
        pendingLift = false
        dragValue = nil
        releaseSent = true
        moved = false
        startValue = nil
        lastChangeValue = nil
        releasedValue = nil
        staleBurstValue = nil
        ignoreStaleUntil = nil
        quietUntil = now.addingTimeInterval(Self.postReleaseQuietInterval)
    }

    mutating func reset() {
        isDragging = false
        dragValue = nil
        fingerIsDown = false
        pendingLift = false
        suppressed = false
        releaseSent = false
        moved = false
        startValue = nil
        lastChangeValue = nil
        quietUntil = nil
        releasedValue = nil
        staleBurstValue = nil
        ignoreStaleUntil = nil
    }

    private mutating func begin(displayedValue: Double) -> [Action] {
        guard !isDragging else { return [] }
        isDragging = true
        releaseSent = false
        if dragValue == nil {
            dragValue = displayedValue
        }
        if startValue == nil {
            startValue = dragValue
        }
        if lastChangeValue == nil {
            lastChangeValue = dragValue
        }
        return []
    }

    /// Returns true when the thumb moved and a release should be sent.
    private mutating func beginLift(now: Date) -> Bool {
        if pendingLift {
            return true
        }
        let blocked = suppressed
        fingerIsDown = false
        suppressed = false
        if blocked {
            isDragging = false
            dragValue = nil
            pendingLift = false
            beginQuietPeriod(now: now)
            return false
        }
        guard isDragging || dragValue != nil else {
            // A release already started the quiet period. Pushing it forward
            // drops every later drag that begins before the new deadline.
            if !isQuiet(now: now) {
                beginQuietPeriod(now: now)
            }
            releaseSent = true
            pendingLift = false
            return false
        }
        pendingLift = true
        return true
    }

    private mutating func finish(displayedValue: Double, now: Date) -> [Action] {
        guard !releaseSent else { return [] }
        guard isDragging || dragValue != nil else { return [] }
        let value = dragValue ?? displayedValue
        let shouldSend = moved
        let burstSource = startValue
        releaseSent = true
        isDragging = false
        pendingLift = false
        dragValue = nil
        lastChangeValue = nil
        moved = false
        startValue = nil
        releasedValue = value
        staleBurstValue = burstSource
        ignoreStaleUntil = now.addingTimeInterval(Self.postReleaseQuietInterval)
        beginQuietPeriod(now: now)
        // A touch that never moves the thumb, including a scroll that starts on the slider,
        // must not send the value the item already has.
        guard shouldSend else { return [] }
        return [.release(value)]
    }

    private mutating func beginQuietPeriod(now: Date) {
        quietUntil = now.addingTimeInterval(Self.postReleaseQuietInterval)
    }

    private func isQuiet(now: Date) -> Bool {
        guard let quietUntil else { return false }
        return now < quietUntil
    }

    /// The post-release burst jumps back to the value from before the drag, many steps away.
    private func isStaleJump(_ newValue: Double, step: Double, now: Date) -> Bool {
        guard let ignoreStaleUntil, now < ignoreStaleUntil else { return false }
        guard approximately(newValue, staleBurstValue, step: step) else { return false }
        guard let anchor = dragValue ?? releasedValue else { return false }
        return abs(newValue - anchor) > max(step * 1.5, 0.001)
    }

    private mutating func blocksSliderCallback(now: Date) -> Bool {
        guard !fingerIsDown else { return false }
        guard let quietUntil else { return false }
        if now < quietUntil {
            return true
        }
        self.quietUntil = nil
        return false
    }

    private func approximately(_ lhs: Double, _ rhs: Double?, step: Double) -> Bool {
        guard let rhs else { return false }
        let tolerance = max(step * 0.5, 0.000_000_1)
        return abs(lhs - rhs) < tolerance
    }
}
