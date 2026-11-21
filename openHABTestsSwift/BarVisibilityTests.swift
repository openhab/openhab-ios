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

@MainActor
struct BarVisibilityTests {
    /// A model whose reveal ends as soon as the test lets it.
    private func model(hidesNavigationBar: Bool = true) -> BarVisibility {
        let bars = BarVisibility(revealDuration: .seconds(8)) { _ in }
        bars.hidesNavigationBar = hidesNavigationBar
        return bars
    }

    @Test func barsAreShownWithoutTheSetting() {
        #expect(!model(hidesNavigationBar: false).isNavigationBarHidden)
    }

    @Test func barsAreHiddenWithTheSetting() {
        #expect(model().isNavigationBarHidden)
    }

    @Test func revealShowsTheBars() {
        let bars = model()
        bars.reveal()
        #expect(!bars.isNavigationBarHidden)
    }

    @Test func barsHideAgainWhenTheRevealEnds() async {
        let bars = model()
        bars.reveal()
        await bars.revealTask?.value
        #expect(bars.isNavigationBarHidden)
    }

    @Test func aSecondRevealStartsTheTimeOver() {
        // A sleep that only ends when its task is cancelled.
        let bars = BarVisibility(revealDuration: .seconds(8)) { _ in try await Task.sleep(for: .seconds(3600)) }
        bars.hidesNavigationBar = true
        bars.reveal()
        let first = bars.revealTask
        bars.reveal()
        #expect(first?.isCancelled == true)
        #expect(bars.revealTask?.isCancelled == false)
        #expect(!bars.isNavigationBarHidden)
    }

    @Test func expireHidesTheBars() {
        let bars = model()
        bars.reveal()
        bars.expire()
        #expect(bars.isNavigationBarHidden)
    }

    @Test func barsStayWhileTheMenuIsOpen() {
        let bars = model()
        bars.menuIsOpen = true
        #expect(!bars.isNavigationBarHidden)
        bars.menuIsOpen = false
        #expect(bars.isNavigationBarHidden)
    }

    @Test func barsStayWhenTheyAreNeeded() {
        let bars = model()
        bars.needsBars = true
        #expect(!bars.isNavigationBarHidden)
        bars.needsBars = false
        #expect(bars.isNavigationBarHidden)
    }

    @Test func guidedAccessHidesTheBarsWithoutTheSetting() {
        let bars = model(hidesNavigationBar: false)
        bars.isInGuidedAccess = true
        #expect(bars.isNavigationBarHidden)
    }

    @Test func guidedAccessTurnsTheGestureOff() {
        let bars = model()
        #expect(bars.allowsReveal)
        bars.isInGuidedAccess = true
        #expect(!bars.allowsReveal)
        bars.reveal()
        #expect(bars.isNavigationBarHidden)
    }

    @Test func theGestureDoesNothingWithoutTheSetting() {
        let bars = model(hidesNavigationBar: false)
        #expect(!bars.allowsReveal)
    }

    /// Guided Access must not hide the indicator of an error either.
    @Test func guidedAccessStillShowsTheBarsForAnError() {
        let bars = model()
        bars.isInGuidedAccess = true
        bars.needsBars = true
        #expect(!bars.isNavigationBarHidden)
    }

    @Test func aPageWithoutNavbarHidesTheBarsWithoutTheSetting() {
        let bars = model(hidesNavigationBar: false)
        bars.pageHidesBars = true
        #expect(bars.isNavigationBarHidden)
        #expect(bars.allowsReveal)
    }

    @Test func theGestureBringsBackTheBarsOfAPageWithoutNavbar() {
        let bars = model(hidesNavigationBar: false)
        bars.pageHidesBars = true
        bars.reveal()
        #expect(!bars.isNavigationBarHidden)
    }

    @Test func leavingThePageShowsTheBarsAgain() {
        let bars = model(hidesNavigationBar: false)
        bars.pageHidesBars = true
        bars.pageHidesBars = false
        #expect(!bars.isNavigationBarHidden)
    }

    @Test func theWayOutIsExplainedOnce() {
        let bars = model(hidesNavigationBar: false)
        #expect(bars.takeExitHint())
        #expect(!bars.takeExitHint())
    }

    @Test func nothingIsHiddenWhileAssistiveTechnologyIsOn() {
        let bars = model()
        bars.isAssistiveTechnologyActive = true
        #expect(!bars.isNavigationBarHidden)
    }

    @Test func theBarsOfAPageWithoutNavbarStayWithAssistiveTechnology() {
        let bars = model(hidesNavigationBar: false)
        bars.pageHidesBars = true
        bars.isAssistiveTechnologyActive = true
        #expect(!bars.isNavigationBarHidden)
    }

    @Test func assistiveTechnologyBeatsGuidedAccess() {
        let bars = model(hidesNavigationBar: false)
        bars.isInGuidedAccess = true
        bars.isAssistiveTechnologyActive = true
        #expect(!bars.isNavigationBarHidden)
    }

    @Test func theBarsHideAgainWhenAssistiveTechnologyTurnsOff() {
        let bars = model()
        bars.isAssistiveTechnologyActive = true
        bars.isAssistiveTechnologyActive = false
        #expect(bars.isNavigationBarHidden)
    }

    @Test func theGestureIsOffWithAssistiveTechnology() {
        let bars = model()
        bars.isAssistiveTechnologyActive = true
        #expect(!bars.allowsReveal)
    }
}
