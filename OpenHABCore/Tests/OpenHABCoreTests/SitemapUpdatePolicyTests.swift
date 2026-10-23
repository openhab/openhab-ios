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
@testable import OpenHABCore
import Testing

struct SitemapUpdatePolicyTests {
    @Test("Follows sitemap events from openHAB 3", arguments: [
        (nil, false), (2, false), (3, true), (5, true)
    ] as [(Int?, Bool)])
    func usesEvents(serverVersion: Int?, expected: Bool) {
        #expect(SitemapUpdatePolicy.usesEvents(serverVersion: serverVersion) == expected)
    }

    @Test("Falls back to long polling when the server can't send events, whether connected before or not", arguments: [false, true])
    func fallsBackWhenUnsupported(hasConnected: Bool) {
        #expect(SitemapUpdatePolicy.shouldFallBackToLongPolling(after: SitemapSseError.unsupported, hasConnected: hasConnected))
    }

    @Test("Falls back to long polling when the stream never connected")
    func fallsBackWhenNeverConnected() {
        #expect(SitemapUpdatePolicy.shouldFallBackToLongPolling(after: nil, hasConnected: false))
        #expect(SitemapUpdatePolicy.shouldFallBackToLongPolling(after: URLError(.timedOut), hasConnected: false))
    }

    @Test("Keeps the events when a connected stream drops, since it reconnects by itself")
    func keepsEventsAfterDrop() {
        #expect(!SitemapUpdatePolicy.shouldFallBackToLongPolling(after: nil, hasConnected: true))
        #expect(!SitemapUpdatePolicy.shouldFallBackToLongPolling(after: URLError(.networkConnectionLost), hasConnected: true))
    }

    @Test("Reloads the page for an event it can't apply", arguments: [
        (SitemapWidgetEventApplicationResult.applied, false),
        (.unchanged, false),
        (.requiresPageReload, true),
        (.notFound, true)
    ])
    func needsPageReload(result: SitemapWidgetEventApplicationResult, expected: Bool) {
        #expect(SitemapUpdatePolicy.needsPageReload(after: result) == expected)
    }

    @Test("Waits longer after each failed reload, up to 30 seconds", arguments: [
        (1, 1), (2, 2), (3, 4), (5, 16), (6, 30), (20, 30)
    ])
    func reloadRetryDelay(failedAttempts: Int, seconds: Int) {
        #expect(SitemapUpdatePolicy.reloadRetryDelay(afterFailedAttempts: failedAttempts) == .seconds(seconds))
    }

    @Test("An event reaches a widget in a flat list through its frame")
    func appliesEventToFlatList() {
        let child = widget(id: "0000", state: "OFF")
        let frame = widget(id: "00", type: .frame, children: [child])
        let widgets = [frame, child]

        let result = widgets.apply(event: OpenHABSitemapWidgetEvent(widgetId: "0000", state: "ON"))

        #expect(result == .applied)
        #expect(child.state == "ON")
    }

    @Test("An event for a widget that isn't in the list is not found")
    func missingWidgetIsNotFound() {
        let widgets = [widget(id: "0000", state: "OFF")]
        #expect(widgets.apply(event: OpenHABSitemapWidgetEvent(widgetId: "0001", state: "ON")) == .notFound)
    }

    @Test("Hides invisible widgets, and frames without a visible child along with their children")
    func visibleWidgets() {
        let shown = widget(id: "0000", state: "ON")
        let hidden = widget(id: "0001", state: "ON", visibility: false)
        let frame = widget(id: "00", type: .frame, children: [shown, hidden])
        let lonelyChild = widget(id: "0100", state: "ON", visibility: false)
        let emptyFrame = widget(id: "01", type: .frame, children: [lonelyChild])
        var widgets = [OpenHABWidget]()
        widgets.flatten([frame, emptyFrame])

        #expect(sitemapVisibleWidgets(widgets).map(\.widgetId) == ["00", "0000"])
    }

    private func widget(id: String,
                        type: OpenHABWidget.WidgetType = .switchWidget,
                        state: String? = nil,
                        visibility: Bool = true,
                        children: [OpenHABWidget] = []) -> OpenHABWidget {
        OpenHABWidget(
            widgetId: id,
            label: id,
            icon: "",
            type: type,
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
            state: state,
            text: nil,
            legend: nil,
            inputHint: nil,
            encoding: nil,
            item: nil,
            linkedPage: nil,
            mappings: [],
            widgets: children,
            visibility: visibility,
            switchSupport: nil,
            forceAsItem: nil
        )
    }
}
