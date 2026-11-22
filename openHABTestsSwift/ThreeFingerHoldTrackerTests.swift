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

import CoreGraphics
@testable import openHAB
import Testing

struct ThreeFingerHoldTrackerTests {
    private typealias Tracker = ThreeFingerHoldTracker<Int>

    private static let origin = CGPoint(x: 100, y: 100)

    private func tracker() -> Tracker {
        Tracker(allowableMovement: 10)
    }

    /// The touches with the given ids, all at `point`.
    private func touches(_ ids: Int..., at point: CGPoint = origin) -> [Int: CGPoint] {
        Dictionary(uniqueKeysWithValues: ids.map { ($0, point) })
    }

    @Test func waitsUntilThreeFingersAreDown() {
        var tracker = tracker()
        let one = tracker.update(touches(1))
        let two = tracker.update(touches(1, 2))
        #expect(one == .none)
        #expect(two == .none)
        #expect(tracker.phase == .waiting)
    }

    @Test func holdStartsWithTheThirdFinger() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2))
        let action = tracker.update(touches(1, 2, 3))
        #expect(action == .startHold)
        #expect(tracker.phase == .holding)
    }

    /// The fingers may land in any order, however far apart in time: only how many are down counts.
    @Test func startsWhenTheFingersLandAtOnce() {
        var tracker = tracker()
        let action = tracker.update(touches(1, 2, 3))
        #expect(action == .startHold)
    }

    @Test func completesWhenTheHoldTimeIsUp() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2, 3))
        let completed = tracker.holdElapsed()
        #expect(completed)
        #expect(tracker.phase == .completed)
    }

    @Test func doesNotCompleteWithTwoFingers() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2))
        let completed = tracker.holdElapsed()
        #expect(!completed)
        #expect(tracker.phase == .waiting)
    }

    @Test func completesOnlyOnce() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2, 3))
        let first = tracker.holdElapsed()
        let second = tracker.holdElapsed()
        #expect(first)
        #expect(!second)
    }

    @Test func smallMovementIsAllowed() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2, 3))
        var moved = touches(1, 2, 3)
        moved[1] = CGPoint(x: 106, y: 106)
        let action = tracker.update(moved)
        let completed = tracker.holdElapsed()
        #expect(action == .none)
        #expect(completed)
    }

    @Test func movingFartherThanAllowedStartsTheTimeOver() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2, 3))
        var moved = touches(1, 2, 3)
        moved[2] = CGPoint(x: 100, y: 111)
        let action = tracker.update(moved)
        #expect(action == .startHold)
        #expect(tracker.phase == .holding)
    }

    /// The distance counts from where the hold started, so slow drift adds up.
    @Test func driftAddsUp() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2, 3))
        var actions: [Tracker.Action] = []
        for step in 1 ... 5 {
            var moved = touches(1, 2, 3)
            moved[3] = CGPoint(x: 100 + CGFloat(step * 3), y: 100)
            actions.append(tracker.update(moved))
        }
        #expect(actions == [.none, .none, .none, .startHold, .none])
    }

    @Test func liftingAFingerCancelsTheHold() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2, 3))
        let action = tracker.update(touches(1, 2))
        let completed = tracker.holdElapsed()
        #expect(action == .cancelHold)
        #expect(!completed)
    }

    @Test func aFingerThatLandsAgainStartsANewHold() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2, 3))
        _ = tracker.update(touches(1, 2))
        let action = tracker.update(touches(1, 2, 4))
        let completed = tracker.holdElapsed()
        #expect(action == .startHold)
        #expect(completed)
    }

    /// Another finger is the same hold with another finger.
    @Test func aFourthFingerStartsTheTimeOver() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2, 3))
        let action = tracker.update(touches(1, 2, 3, 4))
        let completed = tracker.holdElapsed()
        #expect(action == .startHold)
        #expect(completed)
    }

    @Test func aFingerReplacedAtOnceStartsTheTimeOver() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2, 3))
        let action = tracker.update(touches(1, 2, 4))
        #expect(action == .startHold)
    }

    /// The fingers stay on the screen after the hold took; that must not start another.
    @Test func doesNothingMoreUntilTheFingersLift() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2, 3))
        _ = tracker.holdElapsed()
        let stillDown = tracker.update(touches(1, 2, 3))
        let lifted = tracker.update(touches(1, 2))
        let again = tracker.update(touches(1, 2, 3))
        #expect(stillDown == .none)
        #expect(lifted == .none)
        #expect(again == .startHold)
    }

    @Test func resetStartsOver() {
        var tracker = tracker()
        _ = tracker.update(touches(1, 2, 3))
        tracker.reset()
        #expect(tracker.phase == .waiting)
        let action = tracker.update(touches(7, 8, 9))
        #expect(action == .startHold)
    }
}
