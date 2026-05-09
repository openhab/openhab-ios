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

@testable import openHAB
import Testing

// Regression test for the "foreground thundering herd" bug:
// All retained SitemapPageViewModels receiving UIApplication.didBecomeActiveNotification
// and simultaneously restarting page load/polling on app foreground.
//
// Only a visible page (between markAppeared and stopPageHandling) must react to
// refreshOnForeground. Pages that were stopped because they scrolled off-screen
// or were navigated away from must stay silent.
@MainActor
@Suite
struct SitemapPageViewModelForegroundRefreshTests {
    // lastForegroundRefreshAt advances only when the visibility guard passes, making
    // it the right synchronous observable for these tests — no Task.yield needed.

    @Test("refreshOnForeground before markAppeared is a no-op")
    func foregroundRefreshBlockedBeforeAppeared() {
        let vm = SitemapPageViewModel(
            pageUrl: "http://openhab.local/rest/sitemaps/default/home",
            title: "Test"
        )
        let before = vm.lastForegroundRefreshAt
        vm.refreshOnForeground()
        #expect(vm.lastForegroundRefreshAt == before)
    }

    @Test("refreshOnForeground after stopPageHandling is a no-op")
    func foregroundRefreshBlockedAfterStop() {
        let vm = SitemapPageViewModel(
            pageUrl: "http://openhab.local/rest/sitemaps/default/home",
            title: "Test"
        )
        vm.markAppeared()
        vm.stopPageHandling()
        let before = vm.lastForegroundRefreshAt
        vm.refreshOnForeground()
        #expect(vm.lastForegroundRefreshAt == before)
    }

    @Test("refreshOnForeground while visible advances lastForegroundRefreshAt")
    func foregroundRefreshAllowedWhileVisible() {
        let vm = SitemapPageViewModel(
            pageUrl: "http://openhab.local/rest/sitemaps/default/home",
            title: "Test"
        )
        vm.markAppeared()
        let before = vm.lastForegroundRefreshAt
        vm.refreshOnForeground()
        #expect(vm.lastForegroundRefreshAt > before)
    }
}
