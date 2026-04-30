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

@testable import OpenHABCore
import Testing

struct OpenHABWidgetEventApplicationTests {
    @Test
    func itemOnlySitemapEventUpdatesWidgetState() {
        let widget = OpenHABWidget(
            widgetId: "0600",
            label: "Light",
            icon: "light",
            type: .switchWidget,
            url: nil,
            period: nil,
            minValue: nil,
            maxValue: nil,
            step: nil,
            refresh: nil,
            height: nil,
            isLeaf: nil,
            iconColor: nil,
            labelColor: nil,
            valueColor: nil,
            service: nil,
            state: "ON",
            text: nil,
            legend: nil,
            inputHint: nil,
            encoding: nil,
            item: item(state: "ON"),
            linkedPage: nil,
            mappings: [],
            widgets: [],
            visibility: true,
            switchSupport: true,
            forceAsItem: nil
        )

        let result = widget.apply(event: OpenHABSitemapWidgetEvent(
            widgetId: "0600",
            enrichedItem: item(state: "OFF")
        ))

        #expect(result == .applied)
        #expect(widget.state == "OFF")
        #expect(widget.item?.state == "OFF")
        #expect(widget.displayState.effectiveState == "OFF")
    }

    @Test
    func reloadIconSitemapEventIsAppliedWithoutPageReload() {
        let widget = OpenHABWidget(
            widgetId: "0600",
            label: "Light",
            icon: "light",
            type: .switchWidget,
            url: nil,
            period: nil,
            minValue: nil,
            maxValue: nil,
            step: nil,
            refresh: nil,
            height: nil,
            isLeaf: nil,
            iconColor: nil,
            labelColor: nil,
            valueColor: nil,
            service: nil,
            state: "ON",
            text: nil,
            legend: nil,
            inputHint: nil,
            encoding: nil,
            item: item(state: "ON"),
            linkedPage: nil,
            mappings: [],
            widgets: [],
            visibility: true,
            switchSupport: true,
            forceAsItem: nil
        )

        // reloadIcon:true must NOT trigger a page reload — the server sends it on
        // virtually every SSE event (icon URL may change with state), so treating it
        // as a reload trigger causes a reload storm. Only descriptionChanged:true
        // warrants a full reload.
        let result = widget.apply(event: OpenHABSitemapWidgetEvent(
            widgetId: "0600",
            reloadIcon: true
        ))

        #expect(result == .applied)
    }

    @Test
    func descriptionChangedSitemapEventRequiresPageReload() {
        let widget = OpenHABWidget(
            widgetId: "0600",
            label: "Light",
            icon: "light",
            type: .switchWidget,
            url: nil,
            period: nil,
            minValue: nil,
            maxValue: nil,
            step: nil,
            refresh: nil,
            height: nil,
            isLeaf: nil,
            iconColor: nil,
            labelColor: nil,
            valueColor: nil,
            service: nil,
            state: "ON",
            text: nil,
            legend: nil,
            inputHint: nil,
            encoding: nil,
            item: item(state: "ON"),
            linkedPage: nil,
            mappings: [],
            widgets: [],
            visibility: true,
            switchSupport: true,
            forceAsItem: nil
        )

        let result = widget.apply(event: OpenHABSitemapWidgetEvent(
            widgetId: "0600",
            descriptionChanged: true
        ))

        #expect(result == .requiresPageReload)
    }

    private func item(state: String) -> OpenHABItem {
        OpenHABItem(
            name: "LightItem",
            type: "Switch",
            state: state,
            link: "",
            label: "Light",
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
    }
}
