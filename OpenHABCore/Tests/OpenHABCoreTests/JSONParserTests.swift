// Copyright (c) 2010-2023 Contributors to the openHAB project
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

// swiftlint:disable type_body_length
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
            let codingData = try decoder.decode([OpenHABSitemap.CodingData].self, from: data)
            XCTAssertEqual(codingData[0].openHABSitemap.homepageLink, "https://192.168.2.63:8444/rest/sitemaps/myHome/myHome", "Sitemap properly parsed")
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
            let codingData = try decoder.decode([OpenHABSitemap.CodingData].self, from: data)
            XCTAssertEqual(codingData[0].openHABSitemap.homepageLink, "http://192.xxx:8080/rest/sitemaps/Haus/Haus", "Sitemap properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testJSONItem() {
        let json = """
                {
                    "link": "https://192.168.2.63:8444/rest/items/lcnLightSwitch5_1",
                    "state": "OFF",
                    "stateDescription": {
                        "pattern": "Kellertest",
                        "readOnly": false,
                        "options": []
                    },
                    "editable": false,
                    "type": "Switch",
                    "name": "lcnLightSwitch5_1",
                    "label": "Licht Treppe Keller-EG",
                    "tags": [
                    "Lighting"
                    ],
                    "groupNames": [
                    "G_PresenceSimulation",
                    "gLcn"
                    ]
                }
        """.data(using: .utf8)!

        do {
            let codingData = try decoder.decode(OpenHABItem.CodingData.self, from: json)
            XCTAssertEqual(codingData.type, "Switch", "Item properly parsed")
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

    func testJSONWidget() {
        let json = """
                {
                "widgetId": "0000",
                "type": "Switch",
                "label": "Licht Treppe Keller-EG [Kellertest]",
                "icon": "switch",
                "mappings": [],
                "item": {
                    "link": "https://192.168.2.63:8444/rest/items/lcnLightSwitch5_1",
                    "state": "OFF",
                    "stateDescription": {
                        "pattern": "Kellertest",
                        "readOnly": false,
                        "options": []
                    },
                    "editable": false,
                    "type": "Switch",
                    "name": "lcnLightSwitch5_1",
                    "label": "Licht Treppe Keller-EG",
                    "tags": [
                        "Lighting"
                    ],
                    "groupNames": [
                        "G_PresenceSimulation",
                        "gLcn"
                    ]
                },
                "widgets": []
                }
        """.data(using: .utf8)!

        do {
            let codingData = try decoder.decode(OpenHABWidget.CodingData.self, from: json)
            XCTAssertEqual(codingData.widgetId, "0000", "Widget properly parsed")
            XCTAssertEqual(codingData.item?.stateDescription?.readOnly, false)
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testLinkedPage() {
        let json = """
        {"id": "1302", "title": "EG Süd", "icon": "rollershutter", "link": "https://192.168.2.63:8444/rest/sitemaps/myHome/1302"}
        """
        let data = Data(json.utf8)
        do {
            let decoded = try decoder.decode(OpenHABLinkedPage.self, from: data)
            XCTAssertEqual(decoded.pageId, "1302", "LinkedPage properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testItem() {
        let json = """
        {"link": "https://192.168.2.63:8444/rest/items/lcnDFFOst", "state": "100.0", "editable": false, "type": "Rollershutter", "name": "lcnDFFOst", "label": "DFF Arbeitszimmer", "tags": [], "groupNames": [ "gDZ", "gDFF", "gLcn"]}
        """
        let data = Data(json.utf8)
        do {
            let decoded = try decoder.decode(OpenHABItem.CodingData.self, from: data)
            XCTAssertEqual(decoded.name, "lcnDFFOst", "LinkedPage properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testJSONLinkedPage() {
        let json = """
                {   "id": "1304",
            "title": "EG West",
            "icon": "rollershutter",
            "link": "https://192.168.2.63:8444/rest/sitemaps/myHome/1304",
            "leaf": true,
            "timeout": false,
            "widgets": [
            {
            "widgetId": "130400",
            "type": "Switch",
            "label": "Jalousie WZ West links",
            "icon": "rollershutter",
            "mappings": [],
            "item": {
            "link": "https://192.168.2.63:8444/rest/items/lcnJalousieWZWestLinks",
            "state": "0.0",
            "editable": false,
            "type": "Rollershutter",
            "name": "lcnJalousieWZWestLinks",
            "label": "Jalousie WZ West links",
            "tags": [],
            "groupNames": [
            "gWZ",
            "gEGJalousien",
            "gHausJalousie",
            "gJalousienWest",
            "gEGJalousienWest",
            "gLcn"
            ]
            },
            "widgets": []
            },
            {
            "widgetId": "130401",
            "type": "Switch",
            "label": "Jalousie WZ West Mitte",
            "icon": "rollershutter",
            "mappings": [],
            "item": {
            "link": "https://192.168.2.63:8444/rest/items/lcnJalousieWZWestMitte",
            "state": "0.0",
            "editable": false,
            "type": "Rollershutter",
            "name": "lcnJalousieWZWestMitte",
            "label": "Jalousie WZ West Mitte",
            "tags": [],
            "groupNames": [
            "gWZ",
            "gEGJalousien",
            "gHausJalousie",
            "gJalousienWest",
            "gEGJalousienWest",
            "gLcn"
            ]
            },
            "widgets": []
            },
            {
            "widgetId": "130402",
            "type": "Switch",
            "label": "Jalousie WZ West rechts",
            "icon": "rollershutter",
            "mappings": [],
            "item": {
            "link": "https://192.168.2.63:8444/rest/items/lcnJalousieWZWestRechts",
            "state": "0.0",
            "editable": false,
            "type": "Rollershutter",
            "name": "lcnJalousieWZWestRechts",
            "label": "Jalousie WZ West rechts",
            "tags": [],
            "groupNames": [
            "gWZ",
            "gEGJalousien",
            "gHausJalousie",
            "gJalousienWest",
            "gEGJalousienWest",
            "gLcn"
            ]
            },
            "widgets": []
            }
            ]
        }
        """.data(using: .utf8)!
        do {
            let codingData = try decoder.decode(OpenHABLinkedPage.self, from: json)
            XCTAssertEqual(codingData.pageId, "1304", "OpenHABLinkedPage properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testJSONWidgetMapping() {
        let json = """
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
        """.data(using: .utf8)!
        do {
            let codingData = try decoder.decode([OpenHABWidgetMapping].self, from: json)
            XCTAssertEqual(codingData[0].label, "Overwrite", "WidgetMapping properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testJSONWidget2() {
        let json = """
        {
            "widgetId": "01",
            "type": "Frame",
            "label": "Eingang",
            "icon": "frame",
            "mappings": [],
            "widgets": [
            {
            "widgetId": "0100",
            "type": "Switch",
            "label": "Licht Eingang",
            "icon": "switch",
            "mappings": [],
            "item": {
            "link": "https://192.168.2.63:8444/rest/items/lcnLightSwitch17_1",
            "state": "ON",
            "editable": false,
            "type": "Switch",
            "name": "lcnLightSwitch17_1",
            "label": "Licht Eingang",
            "tags": [
            "Lighting"
            ],
            "groupNames": [
            "G_PresenceSimulation",
            "gLcn"
            ]
            },
            "widgets": []
            },
            {
            "widgetId": "0101",
            "type": "Switch",
            "label": "Licht Eingang aussen",
            "icon": "switch",
            "mappings": [],
            "item": {
            "link": "https://192.168.2.63:8444/rest/items/lcnLightSwitch17_2",
            "state": "OFF",
            "editable": false,
            "type": "Switch",
            "name": "lcnLightSwitch17_2",
            "label": "Licht Eingang aussen",
            "tags": [
            "Lighting"
            ],
            "groupNames": [
            "G_PresenceSimulation",
            "gLcn"
            ]
            },
            "widgets": []
            }
            ]
            }
        """.data(using: .utf8)!
        do {
            let codingData = try decoder.decode(OpenHABWidget.CodingData.self, from: json)
            XCTAssertEqual(codingData.widgetId, "01", "Widget properly parsed")
            XCTAssert(codingData.mappings.isEmpty, "No mappings found")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testJSONSitemapPage() {
        do {
            let codingData = try decoder.decode(OpenHABSitemapPage.CodingData.self, from: jsonSitemap)
            XCTAssertEqual(codingData.leaf, false, "OpenHABSitemapPage properly parsed")
            XCTAssertEqual(codingData.widgets?[0].widgetId, "00", "widget properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testJSONSitemapPage2() {
        do {
            let codingData = try decoder.decode(OpenHABSitemapPage.CodingData.self, from: jsonSitemap2)
            XCTAssertEqual(codingData.leaf, false, "OpenHABSitemapPage properly parsed")
            XCTAssertEqual(codingData.widgets?[0].widgetId, "00", "widget properly parsed")
            XCTAssertEqual(codingData.widgets?[4].widgets[3].item?.stateDescription?.options?[0].label, "New moon", "State description properly parsed")

        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    // swiftlint:disable line_length

    func testWatchSitemap() {
        let json = """
        {"name":"watch","label":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch","homepage":{"id":"watch","title":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch/watch","leaf":false,"timeout":false,"widgets":[{"widgetId":"00","type":"Frame","label":"Ground floor","icon":"frame","mappings":[],"widgets":[{"widgetId":"0000","type":"Switch","label":"Licht Oberlicht","icon":"switch","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch14_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch14_1","label":"Licht Oberlicht","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0001","type":"Switch","label":"Licht Keller WC Decke","icon":"colorpicker","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch6_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch6_1","label":"Licht Keller WC Decke","category":"colorpicker","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]}]}]}}
        """.data(using: .utf8)!
        do {
            let codingData = try decoder.decode(OpenHABSitemap.CodingData.self, from: json)
            XCTAssertEqual(codingData.page.link, "https://192.168.2.15:8444/rest/sitemaps/watch/watch", "OpenHABSitemapPage properly parsed")
            //        XCTAssert(codingData.openHABSitemapPage. widgets[0].type == "Frame", "")
            //        XCTAssert(.widgets[0].linkedPage?.pageId == "0000", "widget properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    // swiftlint:enable line_length

    func testParsingforRollerShutter() {
        let jsonInputForGroup = """
        {
            "id": "watch",
            "title": "Watch",
            "link": "https://server/rest/sitemaps/watch/watch",
            "leaf": true,
            "timeout": false,
            "widgets": [
            {
                "widgetId": "00",
                "type": "Switch",
                "label": "Rollladen Erdgeschoss",
                "icon": "blinds",
                "mappings": [],
                "item": {
                    "members": [],
                    "groupType": "Rollershutter",
                    "function": {
                        "name": "EQUALITY"
                    },
                    "link": "https://server/rest/items/gRollladen_EG",
                    "state": "UNDEF",
                    "editable": false,
                    "type": "Group",
                    "name": "gRollladen_EG",
                    "label": "Rollladen Erdgeschoss",
                    "category": "blinds",
                    "tags": [],
                    "groupNames": []
                },
                "widgets": []
            }
            ]
        }
        """
        let data = Data(jsonInputForGroup.utf8)
        do {
            let codingData = try decoder.decode(OpenHABSitemapPage.CodingData.self, from: data)
            let widget = codingData.widgets?[0]
            XCTAssert(widget?.item?.type == "Group" && widget?.item?.groupType == "Rollershutter", "")
            XCTAssertEqual(codingData.widgets?[0].item?.groupType, "Rollershutter")
            XCTAssertEqual(codingData.widgets?[0].item?.type, "Group")
        } catch {
            XCTFail("Failed parsing")
        }
    }

    func testJSONLargeSitemapParseSwift() throws {
        let log = OSLog(
            subsystem: "org.openhab.app",
            category: "RecordDecoding"
        )

        if #available(iOS 12, *) {
            let signpostID = OSSignpostID(log: log)

            let jsonFile = "LargeSitemap"
            os_signpost(
                .begin,
                log: log,
                name: "Read File",
                signpostID: signpostID,
                "%{public}s",
                jsonFile
            )

            let testBundle = Bundle.module
            let url = testBundle.url(forResource: jsonFile, withExtension: "json")
            let contents = try Data(contentsOf: url!)
            os_signpost(
                .end,
                log: log,
                name: "Read File",
                signpostID: signpostID,
                "%{public}s",
                jsonFile
            )

            os_signpost(
                .begin,
                log: log,
                name: "Decode JSON",
                signpostID: signpostID,
                "Begin"
            )
            let codingData = try decoder.decode(OpenHABSitemap.CodingData.self, from: contents)
            os_signpost(
                .end,
                log: log,
                name: "Decode JSON",
                signpostID: signpostID,
                "End"
            )

            let widgets: [OpenHABWidget.CodingData] = try XCTUnwrap(codingData.page.widgets)
            let widget = widgets[0]
            XCTAssertEqual(widget.label, "Flat Scenes")
            XCTAssertEqual(widget.widgets[0].label, "Scenes")
            XCTAssertEqual(codingData.page.link, "https://192.168.0.9:8443/rest/sitemaps/default/default")
            let widget2 = widgets[10]
            XCTAssertEqual(widget2.widgets[0].label, "Admin Items")
        }
    }

    func testItemWithDescription() {
        let json = """
        {
        "widgetId": "0000",
        "type": "Switch",
        "label": "Licht Treppe Keller-EG [Kellertest]",
        "icon": "switch",
        "mappings": [],
        "item": {"link":"http://eye:8080/rest/items/Master_Motion_Sensor",
            "state":"OFF",
        "stateDescription": {"readOnly":true,
        "options":[{"value":"OFF","label":"OK"},{"value":"ON","label":"Alarm"}]},
            "editable":false,
            "type":"Switch",
            "name":"Master_Motion_Sensor",
            "label":"Master Movement",
            "category":"motion",
            "tags":[],
            "groupNames":["gMotion","gMotion2","LightMotionSensors"]
        },
        "widgets": []
        }
        """
        let data = Data(json.utf8)

        do {
            var widget: OpenHABWidget
            widget = try {
                let widgetCodingData = try decoder.decode(OpenHABWidget.CodingData.self, from: data)
                return widgetCodingData.openHABWidget
            }()

            XCTAssertEqual(widget.mappingsOrItemOptions[0].command, "OFF", "Checking assignment of stateDescription")
            XCTAssertEqual(widget.mappingIndex(byCommand: "ON"), 1, "Checking finding of command")

        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
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
            // var widget: OpenHABServerLinks
            let properties = try decoder.decode(OpenHABServerProperties.self, from: data)

            XCTAssertEqual(properties.version, "3", "Checking version")
            XCTAssertEqual(properties.links[0].type, "uuid", "Checking finding links")
            XCTAssertEqual(properties.linkUrl(byType: "uuid"), "http://192.168.2.15:8081/rest/uuid", "Checking finding link by type")

        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }
}
