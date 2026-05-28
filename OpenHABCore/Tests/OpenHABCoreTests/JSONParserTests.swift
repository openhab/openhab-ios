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
import os.signpost
import Testing

struct JSONParserTests {
    let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder.makeISO8601TolerantDecoder()
    }

    @Test func jSONSitemapDecoder() throws {
        let data = Data(jsonSitemap3.utf8)
        let codingData = try decoder.decode([Components.Schemas.SitemapDTO].self, from: data)
        #expect(codingData[0].homepage?.link == "https://192.168.2.63:8444/rest/sitemaps/myHome/myHome")
    }

    /// Version 2.1 is without timeout
    /// Contributed by Tobi-1234 in #348
    @Test func jSONShortSitemapDecoder() throws {
        let json = """
        [{"name":"Haus","label":"HauptmenÃ¼","link":"http://192.xxxx:8080/rest/sitemaps/Haus","homepage":{"link":"http://192.xxx:8080/rest/sitemaps/Haus/Haus","leaf":false,"widgets":[]}},{"name":"_default","label":"Home","link":"http://192.Xxx:8080/rest/sitemaps/_default","homepage":{"link":"http://192.Xxxx:8080/rest/sitemaps/_default/_default","leaf":false,"widgets":[]}}]
        """
        let data = Data(json.utf8)
        let codingData = try decoder.decode([Components.Schemas.SitemapDTO].self, from: data)
        #expect(codingData[0].homepage?.link == "http://192.xxx:8080/rest/sitemaps/Haus/Haus")
    }

    @Test func widgetMapping() throws {
        let json = """
        [{"command": "0","label": "Overwrite"}, {"command": "1","label": "Calendar"}]
        """
        let data = Data(json.utf8)
        let decoded = try decoder.decode([OpenHABWidgetMapping].self, from: data)
        #expect(decoded[0].label == "Overwrite")
    }

    @Test func jSONWidgetMapping() throws {
        let json = Data("""
        [
            {
                "command": "0",
                "label": "Overwrite"
            },
            {
                "command": "1",
                "label": "Kalender"
            },
            {
                "command": "2",
                "label": "Automatik"
            }
        ]
        """.utf8)
        let codingData = try decoder.decode([OpenHABWidgetMapping].self, from: json)
        #expect(codingData[0].label == "Overwrite")
    }

    @Test func watchSitemap() throws {
        // swiftlint:disable line_length
        let json = Data("""
        {"name":"watch","label":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch","homepage":{"id":"watch","title":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch/watch","leaf":false,"timeout":false,"widgets":[{"widgetId":"00","type":"Frame","label":"Ground floor","icon":"frame","mappings":[],"widgets":[{"widgetId":"0000","type":"Switch","label":"Licht Oberlicht","icon":"switch","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch14_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch14_1","label":"Licht Oberlicht","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0001","type":"Switch","label":"Licht Keller WC Decke","icon":"colorpicker","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch6_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch6_1","label":"Licht Keller WC Decke","category":"colorpicker","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]}]}]}}
        """.utf8)
        // swiftlint:enable line_length
        let codingData = try decoder.decode(Components.Schemas.SitemapDTO.self, from: json)
        #expect(codingData.homepage?.link == "https://192.168.2.15:8444/rest/sitemaps/watch/watch")
    }

    @Test func jSONLargeSitemapParseSwift() throws {
        let jsonFile = "LargeSitemap"
        let testBundle = Bundle.module
        let url = try #require(testBundle.url(forResource: jsonFile, withExtension: "json"))

        let signposter = OSSignposter(subsystem: "org.openhab.app", category: "RecordDecoding")

        let state = signposter.beginInterval("Read File")
        let contents = try Data(contentsOf: url)
        signposter.endInterval("Read File", state)

        let state2 = signposter.beginInterval("Decode JSON")
        let codingData = try decoder.decode(Components.Schemas.SitemapDTO.self, from: contents)
        signposter.endInterval("Decode JSON", state2)

        let widgets = try #require(codingData.homepage?.widgets)
        let widget = widgets[0]
        #expect(widget.label == "Flat Scenes")
        #expect(widget.widgets?[0].label == "Scenes")
        #expect(codingData.homepage?.link == "https://192.168.0.9:8443/rest/sitemaps/default/default")
        let widget2 = widgets[10]
        #expect(widget2.widgets?[0].label == "Admin Items")
    }

    @Test func serverVersion() throws {
        let json = """
        {"version":"3", "links":[{"type":"uuid","url":"http://192.168.2.15:8081/rest/uuid"},
        {"type":"audio","url":"http://192.168.2.15:8081/rest/audio"},{"type":"bindings","url":"http://192.168.2.15:8081/rest/bindings"},{"type":"channel-types","url":"http://192.168.2.15:8081/rest/channel-types"},{"type":"config-descriptions","url":"http://192.168.2.15:8081/rest/config-descriptions"},{"type":"discovery","url":"http://192.168.2.15:8081/rest/discovery"},
        {"type":"inbox","url":"http://192.168.2.15:8081/rest/inbox"},{"type":"extensions","url":"http://192.168.2.15:8081/rest/extensions"},{"type":"items","url":"http://192.168.2.15:8081/rest/items"},{"type":"links","url":"http://192.168.2.15:8081/rest/links"},{"type":"persistence","url":"http://192.168.2.15:8081/rest/persistence"},{"type":"profile-types","url":"http://192.168.2.15:8081/rest/profile-types"},{"type":"services","url":"http://192.168.2.15:8081/rest/services"},
        {"type":"things","url":"http://192.168.2.15:8081/rest/things"},{"type":"thing-types","url":"http://192.168.2.15:8081/rest/thing-types"},{"type":"sitemaps","url":"http://192.168.2.15:8081/rest/sitemaps"},{"type":"voice","url":"http://192.168.2.15:8081/rest/voice"},{"type":"iconsets","url":"http://192.168.2.15:8081/rest/iconsets"},{"type":"habpanel","url":"http://192.168.2.15:8081/rest/habpanel"}]}
        """
        let data = Data(json.utf8)
        let properties = try decoder.decode(OpenHABServerProperties.self, from: data)

        #expect(properties.version == "3")
        #expect(properties.links[0].type == "uuid")
        #expect(properties.linkUrl(byType: "uuid") == "http://192.168.2.15:8081/rest/uuid")
    }
}
