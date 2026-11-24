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
@testable import openHAB
import Testing

struct SliderDragCoordinatorTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func releaseSendsTheLatestValueOnceThenIgnoresTheStaleBurst() {
        var coordinator = SliderDragCoordinator()

        _ = coordinator.fingerChanged(displayedValue: 99)
        let moved = coordinator.valueChanged(0, displayedValue: 99, step: 1, now: start)
        let ignoredWhileDown = coordinator.editingChanged(false, displayedValue: 99, now: start)
        let released = coordinator.fingerEnded(displayedValue: 99, now: start)
        let settled = coordinator

        let burstTime = start.addingTimeInterval(0.4)
        let lateTrue = coordinator.editingChanged(true, displayedValue: 99, now: burstTime)
        var stale: [SliderDragCoordinator.Action] = []
        for _ in 0 ..< 24 {
            stale += coordinator.editingChanged(false, displayedValue: 99, now: burstTime)
            stale += coordinator.valueChanged(99, displayedValue: 0, step: 1, now: burstTime)
        }

        #expect(moved == [.change(0)])
        #expect(ignoredWhileDown == [])
        #expect(released == [.release(0)])
        #expect(lateTrue == [])
        #expect(stale == [])
        #expect(coordinator == settled)
        #expect(coordinator.isDragging == false)
    }

    @Test
    func repeatedFramesOfTheSameValueSendOneChange() {
        var coordinator = SliderDragCoordinator()
        _ = coordinator.fingerChanged(displayedValue: 0)

        var changes: [SliderDragCoordinator.Action] = []
        for _ in 0 ..< 56 {
            changes += coordinator.valueChanged(50, displayedValue: 0, step: 1, now: start)
        }

        #expect(changes == [.change(50)])
    }

    @Test
    func steppedSliderWithoutAnEditingTrueStillReleasesTheDraggedValue() {
        var coordinator = SliderDragCoordinator()

        let moved = coordinator.valueChanged(0, displayedValue: 99, step: 1, now: start)
        let released = coordinator.editingChanged(false, displayedValue: 99, now: start)
        let lateTrue = coordinator.editingChanged(true, displayedValue: 0, now: start.addingTimeInterval(0.4))
        let twitch = coordinator.valueChanged(99, displayedValue: 0, step: 1, now: start.addingTimeInterval(0.45))

        #expect(moved == [.change(0)])
        #expect(released == [.release(0)])
        #expect(lateTrue == [])
        #expect(twitch == [])
        #expect(coordinator.isDragging == false)
    }

    @Test
    func touchThatDoesNotMoveDoesNotSend() {
        var coordinator = SliderDragCoordinator()
        _ = coordinator.fingerChanged(displayedValue: 40)
        let released = coordinator.fingerEnded(displayedValue: 40, now: start)

        #expect(released == [])
        #expect(coordinator.isDragging == false)
    }

    @Test
    func returningToTheStartValueStillReleasesAfterAMove() {
        var coordinator = SliderDragCoordinator()
        _ = coordinator.fingerChanged(displayedValue: 99)
        _ = coordinator.valueChanged(50, displayedValue: 99, step: 1, now: start)
        _ = coordinator.valueChanged(99, displayedValue: 50, step: 1, now: start)
        let released = coordinator.fingerEnded(displayedValue: 50, now: start)

        #expect(released == [.release(99)])
    }

    @Test
    func idleEchoOfTheCurrentValueDoesNotStartADrag() {
        var coordinator = SliderDragCoordinator()
        let echo = coordinator.valueChanged(50, displayedValue: 50, step: 1, now: start)

        #expect(echo == [])
        #expect(coordinator.isDragging == false)
    }

    @Test
    func serverCancelSuppressesTheTrailingTwitch() {
        var coordinator = SliderDragCoordinator()
        _ = coordinator.fingerChanged(displayedValue: 10)
        _ = coordinator.valueChanged(80, displayedValue: 10, step: 1, now: start)
        coordinator.cancel(now: start)

        let twitch = coordinator.valueChanged(10, displayedValue: 80, step: 1, now: start.addingTimeInterval(0.2))
        let ended = coordinator.fingerEnded(displayedValue: 80, now: start.addingTimeInterval(0.3))

        #expect(twitch == [])
        #expect(ended == [])
        #expect(coordinator.isDragging == false)
    }

    @Test
    func aNewGestureAfterTheQuietPeriodSendsAgain() {
        var coordinator = SliderDragCoordinator()
        _ = coordinator.valueChanged(0, displayedValue: 99, step: 1, now: start)
        _ = coordinator.editingChanged(false, displayedValue: 99, now: start)

        let later = start.addingTimeInterval(1)
        _ = coordinator.editingChanged(true, displayedValue: 0, now: later)
        let moved = coordinator.valueChanged(25, displayedValue: 0, step: 1, now: later)
        let released = coordinator.editingChanged(false, displayedValue: 0, now: later.addingTimeInterval(0.1))

        #expect(moved == [.change(25)])
        #expect(released == [.release(25)])
    }

    @Test
    func gestureEndWhileTheThumbKeepsMovingDoesNotRelease() {
        var coordinator = SliderDragCoordinator()
        _ = coordinator.fingerChanged(displayedValue: 10)
        _ = coordinator.valueChanged(40, displayedValue: 10, step: 1, now: start)

        let waiting = coordinator.fingerMayHaveLifted(now: start)
        let continued = coordinator.valueChanged(41, displayedValue: 40, step: 1, now: start.addingTimeInterval(0.05))
        let committed = coordinator.commitPendingLift(displayedValue: 40, now: start.addingTimeInterval(0.2))

        #expect(waiting)
        #expect(continued == [.change(41)])
        #expect(committed == [])
        #expect(coordinator.isDragging)
        #expect(coordinator.fingerIsDown)
    }

    @Test
    func confirmedLiftIgnoresTheReleaseAnimationAndTheNextDragStillSends() {
        var coordinator = SliderDragCoordinator()
        _ = coordinator.fingerChanged(displayedValue: 99)
        _ = coordinator.valueChanged(0, displayedValue: 99, step: 1, now: start)
        let waiting = coordinator.fingerMayHaveLifted(now: start)
        #expect(waiting)

        let released = coordinator.commitPendingLift(displayedValue: 99, now: start.addingTimeInterval(0.15))
        let burst = coordinator.valueChanged(99, displayedValue: 0, step: 1, now: start.addingTimeInterval(0.4))
        let thumbTwitch = coordinator.valueChanged(1, displayedValue: 0, step: 1, now: start.addingTimeInterval(0.45))

        #expect(released == [.release(0)])
        #expect(burst == [])
        #expect(thumbTwitch == [])
        #expect(coordinator.isDragging == false)
        #expect(coordinator.fingerIsDown == false)

        let again = start.addingTimeInterval(0.5)
        _ = coordinator.fingerChanged(displayedValue: 0)
        let moved = coordinator.valueChanged(40, displayedValue: 0, step: 1, now: again)
        let second = coordinator.fingerEnded(displayedValue: 0, now: again)

        #expect(moved == [.change(40)])
        #expect(second == [.release(40)])
    }

    @Test
    func emptyLiftDuringQuietDoesNotProlongIt() {
        var coordinator = SliderDragCoordinator()
        _ = coordinator.fingerChanged(displayedValue: 10)
        _ = coordinator.valueChanged(25, displayedValue: 10, step: 1, now: start)
        _ = coordinator.fingerEnded(displayedValue: 10, now: start)

        let during = start.addingTimeInterval(0.5)
        let waiting = coordinator.fingerMayHaveLifted(now: during)
        let moved = coordinator.valueChanged(40, displayedValue: 25, step: 1, now: start.addingTimeInterval(0.61))

        #expect(waiting == false)
        #expect(moved == [.change(40)])
    }
}
