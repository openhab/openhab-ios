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

struct WidgetDisplayStateTests {
    @Test
    func usesItemStateWhenWidgetStateIsEmpty() {
        let widget = makeWidget(
            widgetState: "",
            itemState: "ON",
            label: "Kitchen Light [On]"
        )

        let display = widget.displayState

        #expect(display.effectiveState == "ON")
        #expect(display.isOn)
        #expect(display.labelText == "Kitchen Light")
        #expect(display.labelValue == "On")
    }

    @Test
    func widgetStateOverridesItemState() {
        let widget = makeWidget(
            widgetState: "OFF",
            itemState: "ON",
            label: "Switch"
        )

        let display = widget.displayState

        #expect(display.effectiveState == "OFF")
        #expect(!display.isOn)
    }

    @Test
    func resolvesSelectedMappingFromItemState() {
        let widget = makeWidget(
            widgetState: "",
            itemState: "AUTO",
            label: "Mode",
            mappings: [
                OpenHABWidgetMapping(command: "MANUAL", label: "Manual"),
                OpenHABWidgetMapping(command: "AUTO", label: "Auto")
            ]
        )

        let display = widget.displayState

        #expect(display.selectedIndex == 1)
        #expect(display.selectedLabel == "Auto")
    }

    // MARK: - Helpers

    private func makeWidget(widgetState: String,
                            itemState: String,
                            label: String,
                            mappings: [OpenHABWidgetMapping] = []) -> OpenHABWidget {
        let item = OpenHABItem(
            name: "Item",
            type: "Switch",
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
        return OpenHABWidget(
            widgetId: "widget-id",
            label: label,
            icon: "switch",
            type: .switchWidget,
            url: nil,
            period: nil,
            minValue: 0,
            maxValue: 100,
            step: 1,
            refresh: nil,
            height: nil,
            isLeaf: nil,
            iconColor: nil,
            labelColor: nil,
            valueColor: nil,
            service: nil,
            state: widgetState,
            text: nil,
            legend: nil,
            inputHint: nil,
            encoding: nil,
            item: item,
            linkedPage: nil,
            mappings: mappings,
            widgets: [],
            visibility: true,
            switchSupport: false,
            forceAsItem: nil,
            labelSource: .sitemapDefinition
        )
    }
}
