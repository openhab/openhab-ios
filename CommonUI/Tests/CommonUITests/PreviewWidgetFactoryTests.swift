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

@testable import CommonUI
import OpenHABCore
import Testing

struct PreviewWidgetFactoryTests {
    @Test("Slider fixture includes range and switch support")
    func sliderFixture() {
        let widget = PreviewWidgetFactory.slider(
            label: "Dimmer",
            value: 42,
            minValue: 10,
            maxValue: 90,
            step: 5,
            switchSupport: true,
            pattern: "%d %%"
        )

        #expect(widget.type == .slider)
        #expect(widget.minValue == 10)
        #expect(widget.maxValue == 90)
        #expect(widget.step == 5)
        #expect(widget.switchSupport)
        #expect(widget.pattern == "%d %%")
        #expect(widget.item?.state == "42.0")
    }

    @Test("Segmented fixture sets mappings and selected state")
    func segmentedFixture() {
        let mappings = [
            OpenHABWidgetMapping(command: "ON", label: "ON"),
            OpenHABWidgetMapping(command: "OFF", label: "OFF")
        ]

        let widget = PreviewWidgetFactory.segmented(
            label: "Switch",
            mappings: mappings,
            selectedState: "OFF",
            valueText: "Mode"
        )

        // OpenHABWidget is non-Sendable; intermediate sub-expression captures in #expect crash with -enable-actor-data-race-checks.
        let widgetType = widget.type
        let mappingCount = widget.mappings.count
        let itemState = widget.item?.state
        let labelValue = widget.labelValue
        #expect(widgetType == .switchWidget)
        #expect(mappingCount == 2)
        #expect(itemState == "OFF")
        #expect(labelValue == "Mode")
    }
}
