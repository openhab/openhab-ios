//
//  openHABTestsSwift.swift
//  openHABTestsSwift
//
//  Created by Tim Müller-Seydlitz on 18.01.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import XCTest

class OpenHABTestsSwift: XCTestCase {

    let decoder = JSONDecoder()

    override func setUp() {
        super.setUp()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testNamedColors() {
        XCTAssertEqual("#ff0000", namedColor(toHexString: "red"))
        XCTAssertEqual(UIColor.red, color(fromHexString: "red"))
    }

    func testJSONNotificationDecoder() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        //[{"_id":"5c4229b41cd87d98382869da","message":"Light Küche was changed","__v":0,"created":"2019-01-18T19:32:04.648Z"},

        let json = """
        [{"_id":"5c82e14d2b48ecbf7a7223e0","message":"Light Küche was changed","__v":0,"created":"2019-03-08T21:40:29.412Z"},{"_id":"5c82c9c22b48ecbf7a70f44e","message":"Light Küche was changed","__v":0,"created":"2019-03-08T20:00:02.368Z"},{"_id":"5c82c9c02b48ecbf7a70f42c","message":"Light Küche was changed","__v":0,"created":"2019-03-08T20:00:00.982Z"},{"_id":"5c7fff782b48ecbf7a4dd8e4","message":"Light Küche was changed","__v":0,"created":"2019-03-06T17:12:24.093Z"},{"_id":"5c7ff5c12b48ecbf7a4d56fb","message":"Light Küche was changed","__v":0,"created":"2019-03-06T16:30:57.101Z"},{"_id":"5c7ed0852b48ecbf7a3d2151","message":"Light Küche was changed","__v":0,"created":"2019-03-05T19:39:49.373Z"},{"_id":"5c7d50ba2b48ecbf7a26948f","message":"Light Küche was changed","__v":0,"created":"2019-03-04T16:22:18.473Z"},{"_id":"5c7d50b62b48ecbf7a269455","message":"Light Küche was changed","__v":0,"created":"2019-03-04T16:22:14.321Z"},{"_id":"5c7d50b42b48ecbf7a269442","message":"Light Küche was changed","__v":0,"created":"2019-03-04T16:22:12.468Z"},{"_id":"5c7d507d2b48ecbf7a26916c","message":"Light Küche was changed","__v":0,"created":"2019-03-04T16:21:17.006Z"}]
""".data(using: .utf8)!

        do {
            let codingData = try decoder.decode([OpenHABNotification.CodingData].self, from: json)
            XCTAssert(codingData[0].message == "Light Küche was changed", "Message properly parsed")
        } catch {
            XCTFail("should not throw \(error)")
        }
    }

    func testJSONSitemapDecoder() {
        let json = """
[{"name":"myHome","label":"myHome","link":"https://192.168.2.63:8444/rest/sitemaps/myHome","homepage":{"link":"https://192.168.2.63:8444/rest/sitemaps/myHome/myHome","leaf":false,"timeout":false,"widgets":[]}},{"name":"grafana","label":"grafana","link":"https://192.168.2.63:8444/rest/sitemaps/grafana","homepage":{"link":"https://192.168.2.63:8444/rest/sitemaps/grafana/grafana","leaf":false,"timeout":false,"widgets":[]}},{"name":"_default","label":"Home","link":"https://192.168.2.63:8444/rest/sitemaps/_default","homepage":{"link":"https://192.168.2.63:8444/rest/sitemaps/_default/_default","leaf":false,"timeout":false,"widgets":[]}}]
"""
        let data = Data(json.utf8)
        do {
            let codingData = try decoder.decode([OpenHABSitemap.CodingData].self, from: data)
            XCTAssert(codingData[0].openHABSitemap.homepageLink == "https://192.168.2.63:8444/rest/sitemaps/myHome/myHome", "Sitemap properly parsed")
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
            XCTAssert(codingData.type == "Switch", "Item properly parsed")
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
            XCTAssert(codingData.widgetId == "0000", "Widget properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testHexString() {
        let iPhoneData: Data = "Tim iPhone".data(using: .utf8)!
        let hexWithReduce = iPhoneData.reduce("", {$0 + String(format: "%02X", $1)})
        XCTAssert (hexWithReduce == "54696D206950686F6E65", "hex properly calculated with reduce")
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
            XCTAssert(codingData.pageId == "1304", "OpenHABLinkedPage properly parsed")
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
        XCTAssert(codingData[0].label == "Overwrite", "WidgetMapping properly parsed")
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
            XCTAssert(codingData.widgetId == "01", "Widget properly parsed")
            XCTAssert(codingData.mappings.count == 0, "No mappings found")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

}
