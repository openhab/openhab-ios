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
    private func model(hidesBars: Bool = true) -> BarVisibility {
        let bars = BarVisibility(revealDuration: .seconds(8)) { _ in }
        bars.hidesBars = hidesBars
        return bars
    }

    @Test func barsAreShownWithoutTheSetting() {
        #expect(!model(hidesBars: false).isHidden)
    }

    @Test func barsAreHiddenWithTheSetting() {
        #expect(model().isHidden)
    }

    @Test func revealShowsTheBars() {
        let bars = model()
        bars.reveal()
        #expect(!bars.isHidden)
    }

    @Test func barsHideAgainWhenTheRevealEnds() async {
        let bars = model()
        bars.reveal()
        await bars.revealTask?.value
        #expect(bars.isHidden)
    }

    @Test func aSecondRevealStartsTheTimeOver() {
        // A sleep that only ends when its task is cancelled.
        let bars = BarVisibility(revealDuration: .seconds(8)) { _ in try await Task.sleep(for: .seconds(3600)) }
        bars.hidesBars = true
        bars.reveal()
        let first = bars.revealTask
        bars.reveal()
        #expect(first?.isCancelled == true)
        #expect(bars.revealTask?.isCancelled == false)
        #expect(!bars.isHidden)
    }

    @Test func expireHidesTheBars() {
        let bars = model()
        bars.reveal()
        bars.expire()
        #expect(bars.isHidden)
    }

    @Test func barsStayWhileTheMenuIsOpen() {
        let bars = model()
        bars.menuIsOpen = true
        #expect(!bars.isHidden)
        bars.menuIsOpen = false
        #expect(bars.isHidden)
    }

    @Test func barsStayWhenTheyAreNeeded() {
        let bars = model()
        bars.needsBars = true
        #expect(!bars.isHidden)
        bars.needsBars = false
        #expect(bars.isHidden)
    }
}
