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
    func colorClearsOnStateChangeAwayFromMatchingCondition() {
        // iconcolor/labelcolor/valuecolor=[==ON="orange"]: server includes the colors
        // while ON, then omits them (not "") once the widget goes back to OFF and the
        // condition no longer matches.
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
            state: "OFF",
            text: nil,
            legend: nil,
            inputHint: nil,
            encoding: nil,
            item: item(state: "OFF"),
            linkedPage: nil,
            mappings: [],
            widgets: [],
            visibility: true,
            switchSupport: true,
            forceAsItem: nil
        )

        let onResult = widget.apply(event: OpenHABSitemapWidgetEvent(
            widgetId: "0600",
            labelcolor: "orange",
            valuecolor: "orange",
            iconcolor: "orange",
            state: "ON",
            enrichedItem: item(state: "ON")
        ))
        #expect(onResult == .applied)
        #expect(widget.iconColor == "orange")
        #expect(widget.labelcolor == "orange")
        #expect(widget.valuecolor == "orange")

        let offResult = widget.apply(event: OpenHABSitemapWidgetEvent(
            widgetId: "0600",
            state: "OFF",
            enrichedItem: item(state: "OFF")
        ))
        #expect(offResult == .applied)
        #expect(widget.state == "OFF")
        #expect(widget.iconColor == "")
        #expect(widget.labelcolor == "")
        #expect(widget.valuecolor == "")
    }

    @Test
    func nonStateEventLeavesColorsUntouched() {
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
            iconColor: "orange",
            labelColor: "orange",
            valueColor: "orange",
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

        // An icon-reload-only event carries no state/item, so it must never clear colors
        // that a prior state-driven event set.
        let result = widget.apply(event: OpenHABSitemapWidgetEvent(
            widgetId: "0600",
            reloadIcon: true,
            visibility: true
        ))

        #expect(result == .applied)
        #expect(widget.iconColor == "orange")
        #expect(widget.labelcolor == "orange")
        #expect(widget.valuecolor == "orange")
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

        #expect(result == .unchanged)
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
