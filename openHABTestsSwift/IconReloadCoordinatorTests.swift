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

@MainActor
@Suite
struct IconReloadCoordinatorTests {
    // Each test creates an isolated coordinator instance rather than using the shared
    // singleton, so tests do not interfere with each other.

    @Test("Active with no prior background is a no-op")
    func activeWithNoPriorBackground() {
        let coord = IconReloadCoordinator(observeNotifications: false)
        coord.didBecomeActive(now: .now)
        #expect(coord.reloadEpoch == 0)
    }

    @Test("Short background does not trigger reload")
    func shortBackgroundNoReload() {
        let coord = IconReloadCoordinator(observeNotifications: false)
        let t1 = Date.now
        coord.didEnterBackground(now: t1)
        coord.didBecomeActive(now: t1.addingTimeInterval(IconReloadCoordinator.reloadThreshold - 1))
        #expect(coord.reloadEpoch == 0)
    }

    @Test("Background exactly at threshold triggers reload")
    func backgroundAtThresholdTriggersReload() {
        let coord = IconReloadCoordinator(observeNotifications: false)
        let t1 = Date.now
        coord.didEnterBackground(now: t1)
        coord.didBecomeActive(now: t1.addingTimeInterval(IconReloadCoordinator.reloadThreshold))
        #expect(coord.reloadEpoch == 1)
    }

    @Test("Long background triggers reload")
    func longBackgroundTriggersReload() {
        let coord = IconReloadCoordinator(observeNotifications: false)
        let t1 = Date.now
        coord.didEnterBackground(now: t1)
        coord.didBecomeActive(now: t1.addingTimeInterval(IconReloadCoordinator.reloadThreshold + 1))
        #expect(coord.reloadEpoch == 1)
    }

    @Test("Short background clears timestamp so a later inactive to active cannot use the stale value")
    func shortBackgroundClearsTimestampPreventsStaleReload() {
        let coord = IconReloadCoordinator(observeNotifications: false)
        let t1 = Date.now
        coord.didEnterBackground(now: t1)
        // Returns active quickly — below threshold, must not reload, but must clear the timestamp.
        coord.didBecomeActive(now: t1.addingTimeInterval(30))
        #expect(coord.reloadEpoch == 0)
        // Inactive→active without a new background event: stale timestamp must not trigger reload.
        coord.didBecomeActive(now: t1.addingTimeInterval(90))
        #expect(coord.reloadEpoch == 0)
    }

    @Test("After a reload, subsequent active without new background is a no-op")
    func afterReloadNoSpuriousSecondReload() {
        let coord = IconReloadCoordinator(observeNotifications: false)
        let t1 = Date.now
        coord.didEnterBackground(now: t1)
        coord.didBecomeActive(now: t1.addingTimeInterval(IconReloadCoordinator.reloadThreshold + 1))
        #expect(coord.reloadEpoch == 1)
        coord.didBecomeActive(now: t1.addingTimeInterval(IconReloadCoordinator.reloadThreshold + 10))
        #expect(coord.reloadEpoch == 1)
    }

    @Test("Each long background increments epoch independently")
    func multipleLongBackgroundsEachIncrementEpoch() {
        let coord = IconReloadCoordinator(observeNotifications: false)
        let t1 = Date.now
        coord.didEnterBackground(now: t1)
        coord.didBecomeActive(now: t1.addingTimeInterval(IconReloadCoordinator.reloadThreshold + 1))
        #expect(coord.reloadEpoch == 1)
        let t2 = t1.addingTimeInterval(200)
        coord.didEnterBackground(now: t2)
        coord.didBecomeActive(now: t2.addingTimeInterval(IconReloadCoordinator.reloadThreshold + 1))
        #expect(coord.reloadEpoch == 2)
    }
}
