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
    private static let origin = CGPoint(x: 100, y: 100)

    /// A tracker with the first two fingers down.
    private func trackerWithTwoFingers() -> ThreeFingerHoldTracker<Int> {
        var tracker = ThreeFingerHoldTracker<Int>(allowableMovement: 10)
        tracker.touchDown(1, at: Self.origin)
        tracker.touchDown(2, at: Self.origin)
        return tracker
    }

    @Test func waitsUntilThreeFingersAreDown() {
        let tracker = trackerWithTwoFingers()
        #expect(tracker.phase == .waiting)
    }

    @Test func holdStartsWithTheThirdFinger() {
        var tracker = trackerWithTwoFingers()
        let started = tracker.touchDown(3, at: Self.origin)
        #expect(started)
        #expect(tracker.phase == .holding)
    }

    @Test func completesWhenTheHoldTimeIsUp() {
        var tracker = trackerWithTwoFingers()
        tracker.touchDown(3, at: Self.origin)
        let completed = tracker.holdElapsed()
        #expect(completed)
        #expect(tracker.phase == .completed)
    }

    @Test func doesNotCompleteWithTwoFingers() {
        var tracker = trackerWithTwoFingers()
        let completed = tracker.holdElapsed()
        #expect(!completed)
        #expect(tracker.phase == .waiting)
    }

    @Test func movingFartherThanAllowedFails() {
        var tracker = trackerWithTwoFingers()
        tracker.touchDown(3, at: Self.origin)
        tracker.touchMoved(2, to: CGPoint(x: 100, y: 111))
        #expect(tracker.phase == .failed)
        let completed = tracker.holdElapsed()
        #expect(!completed)
    }

    @Test func smallMovementIsAllowed() {
        var tracker = trackerWithTwoFingers()
        tracker.touchDown(3, at: Self.origin)
        tracker.touchMoved(1, to: CGPoint(x: 106, y: 106))
        #expect(tracker.phase == .holding)
        let completed = tracker.holdElapsed()
        #expect(completed)
    }

    /// The distance counts from where the finger came down, so slow drift adds up.
    @Test func driftAddsUp() {
        var tracker = trackerWithTwoFingers()
        tracker.touchDown(3, at: Self.origin)
        for step in 1 ... 5 {
            tracker.touchMoved(3, to: CGPoint(x: 100 + CGFloat(step * 3), y: 100))
        }
        #expect(tracker.phase == .failed)
    }

    @Test func liftingAFingerEarlyFails() {
        var tracker = trackerWithTwoFingers()
        tracker.touchDown(3, at: Self.origin)
        tracker.touchUp(3)
        #expect(tracker.phase == .failed)
        let completed = tracker.holdElapsed()
        #expect(!completed)
    }

    @Test func aFourthFingerFails() {
        var tracker = trackerWithTwoFingers()
        tracker.touchDown(3, at: Self.origin)
        let started = tracker.touchDown(4, at: Self.origin)
        #expect(!started)
        #expect(tracker.phase == .failed)
    }

    @Test func liftingAFingerBeforeTheThirdLandsKeepsWaiting() {
        var tracker = trackerWithTwoFingers()
        tracker.touchUp(2)
        #expect(tracker.phase == .waiting)
        tracker.touchDown(3, at: Self.origin)
        #expect(tracker.phase == .waiting)
        tracker.touchDown(4, at: Self.origin)
        #expect(tracker.phase == .holding)
    }

    @Test func resetStartsOver() {
        var tracker = trackerWithTwoFingers()
        tracker.touchDown(3, at: Self.origin)
        tracker.touchMoved(3, to: CGPoint(x: 300, y: 300))
        tracker.reset()
        #expect(tracker.phase == .waiting)
        tracker.touchDown(7, at: Self.origin)
        tracker.touchDown(8, at: Self.origin)
        let started = tracker.touchDown(9, at: Self.origin)
        #expect(started)
    }

    @Test func movementOfAnUnknownTouchIsIgnored() {
        var tracker = trackerWithTwoFingers()
        tracker.touchDown(3, at: Self.origin)
        tracker.touchMoved(99, to: CGPoint(x: 900, y: 900))
        #expect(tracker.phase == .holding)
    }
}
