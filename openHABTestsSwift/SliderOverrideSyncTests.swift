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
import OpenHABCore
import Testing

@MainActor
struct SliderOverrideSyncTests {
    @Test
    func clearsSliderOverrideWhenServerCatchesUp() {
        let viewModel = SitemapPageViewModel(pageUrl: "", title: "Preview", pageId: "", widgets: [])
        let itemName = "test_LEDLight_Brightness"
        viewModel.setSliderOverrideValue(86, for: itemName)

        let widget = makeSliderWidget(widgetID: "00", itemName: itemName, itemState: "86.0", step: 1.0)
        let cleared = viewModel.syncSliderOverridesWithServerState(for: [widget])

        #expect(cleared == 1)
        #expect(viewModel.sliderOverrideValue(for: itemName) == nil)
    }

    @Test
    func keepsSliderOverrideWhenServerHasNotCaughtUp() {
        let viewModel = SitemapPageViewModel(pageUrl: "", title: "Preview", pageId: "", widgets: [])
        let itemName = "test_LEDLight_Brightness"
        viewModel.setSliderOverrideValue(86, for: itemName)

        let widget = makeSliderWidget(widgetID: "00", itemName: itemName, itemState: "79.0", step: 1.0)
        let cleared = viewModel.syncSliderOverridesWithServerState(for: [widget])

        #expect(cleared == 0)
        #expect(viewModel.sliderOverrideValue(for: itemName) == 86)
    }
}

private extension SliderOverrideSyncTests {
    func makeSliderWidget(widgetID: String, itemName: String, itemState: String, step: Double) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .slider
        widget.step = step
        widget.item = OpenHABItem(
            name: itemName,
            type: "Dimmer",
            state: itemState,
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
