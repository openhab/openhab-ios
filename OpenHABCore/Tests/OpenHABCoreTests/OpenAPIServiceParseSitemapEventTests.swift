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

import OpenAPIRuntime

@testable import OpenHABCore
import Testing

struct OpenAPIServiceParseSitemapEventTests {
    @Test
    func aliveEventHeaderIsRecognised() {
        let sse = ServerSentEvent(event: "alive", data: nil)

        guard case .alive = OpenAPIService.parseSitemapEvent(sse) else {
            Issue.record("Expected .alive")
            return
        }
    }

    @Test
    func aliveEventPayloadIsRecognised() {
        let sse = ServerSentEvent(data: #"{"TYPE":"ALIVE","sitemapName":"home","pageId":"home"}"#)

        guard case .alive = OpenAPIService.parseSitemapEvent(sse) else {
            Issue.record("Expected .alive")
            return
        }
    }

    @Test
    func sitemapChangedEventIsRecognised() {
        let sse = ServerSentEvent(
            data: #"{"TYPE":"SITEMAP_CHANGED","sitemapName":"home","pageId":"1234"}"#
        )

        guard case let .sitemapChanged(sitemap, pageId) = OpenAPIService.parseSitemapEvent(sse) else {
            Issue.record("Expected .sitemapChanged")
            return
        }
        #expect(sitemap == "home")
        #expect(pageId == "1234")
    }

    @Test
    func widgetEventIsDecoded() {
        let sse = ServerSentEvent(
            data: #"""
            {"widgetId":"0202","label":"Kitchen Light","state":"ON","sitemapName":"home","pageId":"0000"}
            """#
        )

        guard case let .widget(event) = OpenAPIService.parseSitemapEvent(sse) else {
            Issue.record("Expected .widget")
            return
        }
        #expect(event.widgetId == "0202")
        #expect(event.label == "Kitchen Light")
        #expect(event.state == "ON")
        #expect(event.sitemapName == "home")
        #expect(event.pageId == "0000")
    }

    @Test
    func widgetEventWithoutTypeIsNotMisclassifiedAsAlive() {
        // A payload carrying no `TYPE` must never resolve to `.alive`/`.sitemapChanged`
        // even though `SitemapWidgetEvent` has no required properties.
        let sse = ServerSentEvent(data: #"{"widgetId":"0300","state":"42"}"#)

        guard case .widget = OpenAPIService.parseSitemapEvent(sse) else {
            Issue.record("Expected .widget")
            return
        }
    }

    @Test
    func missingDataReturnsNil() {
        #expect(OpenAPIService.parseSitemapEvent(ServerSentEvent(data: nil)) == nil)
    }

    @Test
    func nonJSONPayloadIsReportedAsUnknown() {
        let sse = ServerSentEvent(data: "this is not json")

        guard case let .unknown(raw) = OpenAPIService.parseSitemapEvent(sse) else {
            Issue.record("Expected .unknown")
            return
        }
        #expect(raw == "this is not json")
    }
}
