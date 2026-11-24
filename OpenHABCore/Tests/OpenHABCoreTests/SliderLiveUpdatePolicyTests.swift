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

import OpenHABCore
import Testing

struct SliderLiveUpdatePolicyTests {
    @Test
    func dimmerFollowsTheRealtimeSlidersPreferenceWhenReleaseOnlyIsOmitted() {
        let widget = makeSlider(itemType: "Dimmer", releaseOnly: nil)

        #expect(widget.shouldUseSliderUpdatesDuringMove(realTimeSliders: true))
        #expect(!widget.shouldUseSliderUpdatesDuringMove(realTimeSliders: false))
    }

    @Test
    func explicitReleaseOnlyIgnoresThePreference() {
        let forcedLive = makeSlider(itemType: "Dimmer", releaseOnly: false)
        let forcedRelease = makeSlider(itemType: "Dimmer", releaseOnly: true)

        #expect(forcedLive.shouldUseSliderUpdatesDuringMove(realTimeSliders: false))
        #expect(!forcedRelease.shouldUseSliderUpdatesDuringMove(realTimeSliders: true))
    }

    @Test
    func numberAndColorFollowThePreference() {
        let number = makeSlider(itemType: "Number", releaseOnly: nil)
        let color = makeSlider(itemType: "Color", releaseOnly: nil)

        #expect(number.shouldUseSliderUpdatesDuringMove(realTimeSliders: true))
        #expect(!number.shouldUseSliderUpdatesDuringMove(realTimeSliders: false))
        #expect(color.shouldUseSliderUpdatesDuringMove(realTimeSliders: true))
        #expect(!color.shouldUseSliderUpdatesDuringMove(realTimeSliders: false))
    }

    @Test
    func rollershutterDoesNotSendWhileMovingEvenWhenThePreferenceIsOn() {
        let widget = makeSlider(itemType: "Rollershutter", releaseOnly: nil)

        #expect(!widget.shouldUseSliderUpdatesDuringMove(realTimeSliders: true))
    }

    @Test
    func missingItemDoesNotSendWhileMovingUnlessTheSitemapForcesIt() {
        let omitted = OpenHABWidget()
        omitted.type = .slider

        let forced = OpenHABWidget()
        forced.type = .slider
        forced.releaseOnly = false

        #expect(!omitted.shouldUseSliderUpdatesDuringMove(realTimeSliders: true))
        #expect(forced.shouldUseSliderUpdatesDuringMove(realTimeSliders: false))
    }

    private func makeSlider(itemType: String, releaseOnly: Bool?) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.type = .slider
        widget.releaseOnly = releaseOnly
        widget.item = OpenHABItem(
            name: "Light",
            type: itemType,
            state: "0",
            link: "",
            label: nil,
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
        return widget
    }
}
