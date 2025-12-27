// Copyright (c) 2010-2025 Contributors to the openHAB project
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
import XCTest

// swiftlint:disable:next type_body_length
final class JSONParserTests: XCTestCase {
    let decoder = JSONDecoder()

    override func setUp() {
        super.setUp()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testJSONSitemapDecoder() {
        let data = Data(jsonSitemap3.utf8)
        do {
            let codingData = try decoder.decode([Components.Schemas.SitemapDTO].self, from: data)
            XCTAssertEqual(codingData[0].homepage?.link, "https://192.168.2.63:8444/rest/sitemaps/myHome/myHome", "Sitemap properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    // Version 2.1 is without timeout
    // Contributed by Tobi-1234 in #348
    func testJSONShortSitemapDecoder() {
        let json = """
        [{"name":"Haus","label":"HauptmenÃ¼","link":"http://192.xxxx:8080/rest/sitemaps/Haus","homepage":{"link":"http://192.xxx:8080/rest/sitemaps/Haus/Haus","leaf":false,"widgets":[]}},{"name":"_default","label":"Home","link":"http://192.Xxx:8080/rest/sitemaps/_default","homepage":{"link":"http://192.Xxxx:8080/rest/sitemaps/_default/_default","leaf":false,"widgets":[]}}]
        """
        let data = Data(json.utf8)
        do {
            let codingData = try decoder.decode([Components.Schemas.SitemapDTO].self, from: data)
            XCTAssertEqual(codingData[0].homepage?.link, "http://192.xxx:8080/rest/sitemaps/Haus/Haus", "Sitemap properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testWidgetMapping() {
        let json = """
        [{"command": "0","label": "Overwrite"}, {"command": "1","label": "Calendar"}]
        """
        let data = Data(json.utf8)
        do {
            let decoded = try decoder.decode([OpenHABWidgetMapping].self, from: data)
            XCTAssertEqual(decoded[0].label, "Overwrite", "WidgetMapping properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testJSONWidgetMapping() {
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
        do {
            let codingData = try decoder.decode([OpenHABWidgetMapping].self, from: json)
            XCTAssertEqual(codingData[0].label, "Overwrite", "WidgetMapping properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    // swiftlint:disable line_length

    func testWatchSitemap() {
        let json = Data("""
        {"name":"watch","label":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch","homepage":{"id":"watch","title":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch/watch","leaf":false,"timeout":false,"widgets":[{"widgetId":"00","type":"Frame","label":"Ground floor","icon":"frame","mappings":[],"widgets":[{"widgetId":"0000","type":"Switch","label":"Licht Oberlicht","icon":"switch","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch14_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch14_1","label":"Licht Oberlicht","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0001","type":"Switch","label":"Licht Keller WC Decke","icon":"colorpicker","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch6_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch6_1","label":"Licht Keller WC Decke","category":"colorpicker","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]}]}]}}
        """.utf8)
        do {
            let codingData = try decoder.decode(Components.Schemas.SitemapDTO.self, from: json)
            XCTAssertEqual(codingData.homepage?.link, "https://192.168.2.15:8444/rest/sitemaps/watch/watch", "OpenHABSitemapPage properly parsed")
            //        XCTAssert(codingData.openHABSitemapPage. widgets[0].type == "Frame", "")
            //        XCTAssert(.widgets[0].linkedPage?.pageId == "0000", "widget properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    // swiftlint:enable line_length

    func testJSONLargeSitemapParseSwift() throws {
        let jsonFile = "LargeSitemap"
        let testBundle = Bundle.module
        let url = try XCTUnwrap(testBundle.url(forResource: jsonFile, withExtension: "json"))

        let signposter = OSSignposter(subsystem: "org.openhab.app", category: "RecordDecoding")

        let state = signposter.beginInterval("Read File")
        let contents = try Data(contentsOf: url)
        signposter.endInterval("Read File", state)

        let state2 = signposter.beginInterval("Decode JSON")
        let codingData = try decoder.decode(Components.Schemas.SitemapDTO.self, from: contents)
        signposter.endInterval("Decode JSON", state2)

        let widgets = try XCTUnwrap(codingData.homepage?.widgets)
        let widget = widgets[0]
        XCTAssertEqual(widget.label, "Flat Scenes")
        XCTAssertEqual(widget.widgets?[0].label, "Scenes")
        XCTAssertEqual(codingData.homepage?.link, "https://192.168.0.9:8443/rest/sitemaps/default/default")
        let widget2 = widgets[10]
        XCTAssertEqual(widget2.widgets?[0].label, "Admin Items")
    }

    func testServerVersion() {
        let json = """
        {"version":"3", "links":[{"type":"uuid","url":"http://192.168.2.15:8081/rest/uuid"},
        {"type":"audio","url":"http://192.168.2.15:8081/rest/audio"},{"type":"bindings","url":"http://192.168.2.15:8081/rest/bindings"},{"type":"channel-types","url":"http://192.168.2.15:8081/rest/channel-types"},{"type":"config-descriptions","url":"http://192.168.2.15:8081/rest/config-descriptions"},{"type":"discovery","url":"http://192.168.2.15:8081/rest/discovery"},
        {"type":"inbox","url":"http://192.168.2.15:8081/rest/inbox"},{"type":"extensions","url":"http://192.168.2.15:8081/rest/extensions"},{"type":"items","url":"http://192.168.2.15:8081/rest/items"},{"type":"links","url":"http://192.168.2.15:8081/rest/links"},{"type":"persistence","url":"http://192.168.2.15:8081/rest/persistence"},{"type":"profile-types","url":"http://192.168.2.15:8081/rest/profile-types"},{"type":"services","url":"http://192.168.2.15:8081/rest/services"},
        {"type":"things","url":"http://192.168.2.15:8081/rest/things"},{"type":"thing-types","url":"http://192.168.2.15:8081/rest/thing-types"},{"type":"sitemaps","url":"http://192.168.2.15:8081/rest/sitemaps"},{"type":"voice","url":"http://192.168.2.15:8081/rest/voice"},{"type":"iconsets","url":"http://192.168.2.15:8081/rest/iconsets"},{"type":"habpanel","url":"http://192.168.2.15:8081/rest/habpanel"}]}
        """
        let data = Data(json.utf8)
        do {
            let properties = try decoder.decode(OpenHABServerProperties.self, from: data)

            XCTAssertEqual(properties.version, "3", "Checking version")
            XCTAssertEqual(properties.links[0].type, "uuid", "Checking finding links")
            XCTAssertEqual(properties.linkUrl(byType: "uuid"), "http://192.168.2.15:8081/rest/uuid", "Checking finding link by type")

        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }
}
