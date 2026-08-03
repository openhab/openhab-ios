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
import OpenHABCore
import Testing

struct WidgetMediaImageDescriptorTests {
    @Test
    func chartDescriptorResolvesToChartLink() {
        let item = OpenHABItem(
            name: "TestNumber",
            type: "Number",
            state: "12",
            link: "",
            label: nil,
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
        let widget = OpenHABWidget(
            widgetId: "chart",
            label: "Chart",
            icon: "chart",
            type: .chart,
            url: nil,
            period: "D",
            minValue: nil,
            maxValue: nil,
            step: nil,
            refresh: nil,
            height: nil,
            isLeaf: nil,
            iconColor: nil,
            labelColor: nil,
            valueColor: nil,
            service: "rrd4j",
            state: nil,
            text: nil,
            legend: true,
            inputHint: nil,
            encoding: nil,
            item: item,
            linkedPage: nil,
            mappings: [],
            widgets: [],
            visibility: true,
            switchSupport: nil,
            forceAsItem: false,
            labelSource: .sitemapDefinition,
            releaseOnly: nil
        )

        let descriptor = widget.mediaImageDescriptor
        let payload = descriptor.resolveImagePayload(rootUrl: "https://example.invalid/rest", chartStyle: .light)

        guard case let .link(url) = payload else {
            #expect(Bool(false), "Expected chart payload to resolve to link")
            return
        }
        #expect(url?.absoluteString.contains("/chart") == true)
    }

    // MARK: - Relative URL resolution (regression for TestFlight report, v3.2.72 build 281)

    // Image widgets backed by an item receive a relative proxy URL from the server
    // (e.g. /proxy?siteid=default&widgetId=xxx) when the item state is NULL.
    // URL(string:) silently accepts relative paths, so the bug was a grey placeholder
    // with no network request rather than a load error.

    @Test
    func imageDescriptorResolvesRelativeWidgetUrlAgainstRootUrl() {
        let item = OpenHABItem(
            name: "DoorBird_Snapshot",
            type: "Image",
            state: "NULL",
            link: "",
            label: nil,
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
        let widget = OpenHABWidget(
            widgetId: "w01",
            label: "Snapshot",
            icon: "camera",
            type: .image,
            url: "/proxy?siteid=default&widgetId=w01",
            period: nil,
            minValue: nil,
            maxValue: nil,
            step: nil,
            refresh: 50000,
            height: nil,
            isLeaf: nil,
            iconColor: nil,
            labelColor: nil,
            valueColor: nil,
            service: nil,
            state: nil,
            text: nil,
            legend: nil,
            inputHint: nil,
            encoding: nil,
            item: item,
            linkedPage: nil,
            mappings: [],
            widgets: [],
            visibility: true,
            switchSupport: nil,
            forceAsItem: nil,
            labelSource: .sitemapDefinition,
            releaseOnly: nil
        )

        let payload = widget.mediaImageDescriptor.resolveImagePayload(rootUrl: "http://openhab.local:8080")

        guard case let .link(url) = payload else {
            #expect(Bool(false), "Expected .link payload for relative widget URL")
            return
        }
        #expect(url?.absoluteString == "http://openhab.local:8080/proxy?siteid=default&widgetId=w01")
    }

    @Test
    func imageDescriptorKeepsAbsoluteWidgetUrlUnchanged() {
        let item = OpenHABItem(
            name: "DoorBird_Snapshot",
            type: "Image",
            state: "NULL",
            link: "",
            label: nil,
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
        let widget = OpenHABWidget(
            widgetId: "w02",
            label: "Snapshot",
            icon: "camera",
            type: .image,
            url: "http://doorbird.local/bha-api/image.cgi",
            period: nil,
            minValue: nil,
            maxValue: nil,
            step: nil,
            refresh: 50000,
            height: nil,
            isLeaf: nil,
            iconColor: nil,
            labelColor: nil,
            valueColor: nil,
            service: nil,
            state: nil,
            text: nil,
            legend: nil,
            inputHint: nil,
            encoding: nil,
            item: item,
            linkedPage: nil,
            mappings: [],
            widgets: [],
            visibility: true,
            switchSupport: nil,
            forceAsItem: nil,
            labelSource: .sitemapDefinition,
            releaseOnly: nil
        )

        let payload = widget.mediaImageDescriptor.resolveImagePayload(rootUrl: "http://openhab.local:8080")

        guard case let .link(url) = payload else {
            #expect(Bool(false), "Expected .link payload for absolute widget URL")
            return
        }
        #expect(url?.absoluteString == "http://doorbird.local/bha-api/image.cgi")
    }

    @Test
    func imageDescriptorResolvesRelativeStringItemStateAgainstRootUrl() {
        let item = OpenHABItem(
            name: "Camera_URL",
            type: "String",
            state: "/proxy?siteid=default&widgetId=w03",
            link: "",
            label: nil,
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
        let widget = OpenHABWidget(
            widgetId: "w03",
            label: "Camera",
            icon: "camera",
            type: .image,
            url: "/proxy?siteid=default&widgetId=w03",
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
            state: nil,
            text: nil,
            legend: nil,
            inputHint: nil,
            encoding: nil,
            item: item,
            linkedPage: nil,
            mappings: [],
            widgets: [],
            visibility: true,
            switchSupport: nil,
            forceAsItem: nil,
            labelSource: .sitemapDefinition,
            releaseOnly: nil
        )

        let payload = widget.mediaImageDescriptor.resolveImagePayload(rootUrl: "http://openhab.local:8080")

        guard case let .link(url) = payload else {
            #expect(Bool(false), "Expected .link payload for relative String item URL")
            return
        }
        #expect(url?.absoluteString == "http://openhab.local:8080/proxy?siteid=default&widgetId=w03")
    }

    @Test
    func imageDescriptorUsesEmbeddedItemPayloadWhenAvailable() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let base64 = data.base64EncodedString()
        let item = OpenHABItem(
            name: "ImageItem",
            type: "Image",
            state: "data,\(base64)",
            link: "",
            label: nil,
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
        let widget = OpenHABWidget(
            widgetId: "image",
            label: "Image",
            icon: "image",
            type: .image,
            url: "https://example.invalid/image.jpg",
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
            state: nil,
            text: nil,
            legend: nil,
            inputHint: nil,
            encoding: nil,
            item: item,
            linkedPage: nil,
            mappings: [],
            widgets: [],
            visibility: true,
            switchSupport: nil,
            forceAsItem: nil,
            labelSource: .sitemapDefinition,
            releaseOnly: nil
        )

        let descriptor = widget.mediaImageDescriptor
        let payload = descriptor.resolveImagePayload(rootUrl: "https://example.invalid/rest")

        guard case let .embedded(decoded) = payload else {
            #expect(Bool(false), "Expected image payload to resolve to embedded data")
            return
        }
        #expect(decoded == data)
    }
}
