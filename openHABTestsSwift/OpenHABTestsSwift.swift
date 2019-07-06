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

    func testWidgetMapping() {
        let json = """
[{"command": "0","label": "Overwrite"}, {"command": "1","label": "Calendar"}]
"""
        let data = Data(json.utf8)
        do {
            let decoded = try decoder.decode([OpenHABWidgetMapping].self, from: data)
            XCTAssert(decoded[0].label == "Overwrite", "WidgetMapping properly parsed")
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

    func testLinkedPage() {
        let json = """
{"id": "1302", "title": "EG Süd", "icon": "rollershutter", "link": "https://192.168.2.63:8444/rest/sitemaps/myHome/1302"}
"""
        let data = Data(json.utf8)
        do {
            let decoded = try decoder.decode(OpenHABLinkedPage.self, from: data)
            XCTAssert(decoded.pageId == "1302", "LinkedPage properly parsed")
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
            XCTAssert(decoded.name == "lcnDFFOst", "LinkedPage properly parsed")
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
            XCTAssert(codingData.mappings.isEmpty, "No mappings found")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testJSONSitemapPage() {
        let json = """
    {"id":"myHome","title":"myHome","link":"https://myopenhab.org/rest/sitemaps/myHome/myHome","leaf":false,"timeout":false,"widgets":[{"widgetId":"00","type":"Frame","label":"Treppe","icon":"frame","mappings":[],"widgets":[{"widgetId":"0000","type":"Switch","label":"Licht Treppe Keller-EG [Kellertest]","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch5_1","state":"OFF","stateDescription":{"pattern":"Kellertest","readOnly":false,"options":[]},"editable":false,"type":"Switch","name":"lcnLightSwitch5_1","label":"Licht Treppe Keller-EG","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0001","type":"Switch","label":"Licht Treppe EG-1","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch10_2","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch10_2","label":"Licht Treppe EG-1","tags":["Lighting"],"groupNames":["gLcn"]},"widgets":[]},{"widgetId":"0002","type":"Switch","label":"Licht Treppe 1-2","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch32_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch32_1","label":"Licht Treppe 1-2","tags":["Lighting"],"groupNames":["gLcn"]},"widgets":[]}]},{"widgetId":"01","type":"Frame","label":"Eingang","icon":"frame","mappings":[],"widgets":[{"widgetId":"0100","type":"Switch","label":"Licht Eingang","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch17_1","state":"ON","editable":false,"type":"Switch","name":"lcnLightSwitch17_1","label":"Licht Eingang","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0101","type":"Switch","label":"Licht Eingang aussen","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch17_2","state":"ON","editable":false,"type":"Switch","name":"lcnLightSwitch17_2","label":"Licht Eingang aussen","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]}]},{"widgetId":"02","type":"Frame","label":"WC","icon":"frame","mappings":[],"widgets":[{"widgetId":"0200","type":"Switch","label":"Licht WC EG","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch12_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch12_1","label":"Licht WC EG","tags":["Lighting"],"groupNames":["gLcn"]},"widgets":[]}]},{"widgetId":"03","type":"Frame","label":"Keller","icon":"frame","mappings":[],"widgets":[{"widgetId":"0300","type":"Switch","label":"Licht Keller WC Decke","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch6_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch6_1","label":"Licht Keller WC Decke","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]},{"widgetId":"0301","type":"Switch","label":"Licht Keller WC Spiegel","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch6_2","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch6_2","label":"Licht Keller WC Spiegel","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]},{"widgetId":"0302","type":"Switch","label":"Licht Keller Lager Decke","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch8_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch8_1","label":"Licht Keller Lager Decke","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]},{"widgetId":"0303","type":"Switch","label":"Licht Gäste Decke","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch9_1","state":"ON","editable":false,"type":"Switch","name":"lcnLightSwitch9_1","label":"Licht Gäste Decke","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]},{"widgetId":"0304","type":"Switch","label":"Licht Keller Heizung Decke","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch7_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch7_1","label":"Licht Keller Heizung Decke","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]}]},{"widgetId":"04","type":"Frame","label":"DFF","icon":"frame","mappings":[],"widgets":[{"widgetId":"0400","type":"Switch","label":"DFF Emma","icon":"rollershutter","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnDFFWest","state":"100.0","editable":false,"type":"Rollershutter","name":"lcnDFFWest","label":"DFF Emma","tags":[],"groupNames":["gDZ","gDFF","gLcn"]},"widgets":[]},{"widgetId":"0401","type":"Switch","label":"DFF Arbeitszimmer","icon":"rollershutter","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnDFFOst","state":"100.0","editable":false,"type":"Rollershutter","name":"lcnDFFOst","label":"DFF Arbeitszimmer","tags":[],"groupNames":["gDZ","gDFF","gLcn"]},"widgets":[]}]},{"widgetId":"05","type":"Frame","label":"DG","icon":"frame","mappings":[],"widgets":[{"widgetId":"0500","type":"Switch","label":"Kofferabteil","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitchRel42_8","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitchRel42_8","label":"Kofferabteil","tags":[],"groupNames":["gLcn"]},"widgets":[]},{"widgetId":"0501","type":"Switch","label":"Licht DG Zimmer","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch44_2","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch44_2","label":"Licht DG Zimmer","tags":["Lighting"],"groupNames":["gLcn"]},"widgets":[]},{"widgetId":"0502","type":"Switch","label":"Licht DG Büro Decke","icon":"lightbulb","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch43_2","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch43_2","label":"Licht DG Büro Decke","category":"lightbulb","tags":["Lighting"],"groupNames":["gLcn"]},"widgets":[]},{"widgetId":"0503","type":"Switch","label":"Licht DG Zimmer Decke","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch41_2","state":"ON","editable":false,"type":"Switch","name":"lcnLightSwitch41_2","label":"Licht DG Zimmer Decke","tags":["Lighting"],"groupNames":["gLcn"]},"widgets":[]},{"widgetId":"0504","type":"Switch","label":"Licht DG Zimmer Occhio","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch44_1","state":"ON","editable":false,"type":"Switch","name":"lcnLightSwitch44_1","label":"Licht DG Zimmer Occhio","tags":["Lighting"],"groupNames":["gLcn"]},"widgets":[]}]},{"widgetId":"06","type":"Frame","label":"Schlafzimmer","icon":"frame","mappings":[],"widgets":[{"widgetId":"0600","type":"Switch","label":"Licht SZ Decke","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch37_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch37_1","label":"Licht SZ Decke","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]}]},{"widgetId":"07","type":"Frame","label":"Zimmer Paul","icon":"frame","mappings":[],"widgets":[{"widgetId":"0700","type":"Switch","label":"Licht Zimmer Paul","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch36_2","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch36_2","label":"Licht Zimmer Paul","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0701","type":"Switch","label":"Steckdose Zimmer Paul","icon":"poweroutlet","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnRelay36_1","state":"OFF","editable":false,"type":"Switch","name":"lcnRelay36_1","label":"Steckdose Zimmer Paul","category":"poweroutlet","tags":["Switchable"],"groupNames":["gLcn"]},"widgets":[]}]},{"widgetId":"08","type":"Frame","label":"Wohnzimmer","icon":"frame","mappings":[],"widgets":[{"widgetId":"0800","type":"Switch","label":"Steckdose WZ Nord","icon":"poweroutlet","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnRelayWZNord","state":"OFF","editable":false,"type":"Switch","name":"lcnRelayWZNord","label":"Steckdose WZ Nord","category":"poweroutlet","tags":["Switchable"],"groupNames":["gLcn"]},"widgets":[]}]},{"widgetId":"09","type":"Frame","label":"Küche","icon":"frame","mappings":[],"widgets":[{"widgetId":"0900","type":"Switch","label":"Licht Oberlicht","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch14_1","state":"ON","editable":false,"type":"Switch","name":"lcnLightSwitch14_1","label":"Licht Oberlicht","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0901","type":"Switch","label":"Licht Küche Oberlicht","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch15_1","state":"ON","editable":false,"type":"Switch","name":"lcnLightSwitch15_1","label":"Licht Küche Oberlicht","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0902","type":"Switch","label":"Licht Küche Unterlicht","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch15_2","state":"ON","editable":false,"type":"Switch","name":"lcnLightSwitch15_2","label":"Licht Küche Unterlicht","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0903","type":"Switch","label":"Licht Esstisch","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch20_1","state":"ON","editable":false,"type":"Switch","name":"lcnLightSwitch20_1","label":"Licht Esstisch","tags":[],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0904","type":"Slider","label":"Esstisch [100]","icon":"slider","mappings":[],"switchSupport":false,"sendFrequency":0,"item":{"link":"https://myopenhab.org/rest/items/lcnLightDimmer","state":"100","stateDescription":{"pattern":"%s","readOnly":false,"options":[]},"editable":false,"type":"Dimmer","name":"lcnLightDimmer","label":"Esstisch","tags":["Lighting"],"groupNames":["gLcn"]},"widgets":[]}]},{"widgetId":"10","type":"Frame","label":"Bad","icon":"frame","mappings":[],"widgets":[{"widgetId":"1000","type":"Switch","label":"Licht Bad Decke","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch38_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch38_1","label":"Licht Bad Decke","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"1001","type":"Switch","label":"Licht Bad Spiegel","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightSwitch38_2","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch38_2","label":"Licht Bad Spiegel","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]}]},{"widgetId":"11","type":"Frame","label":"Aussen","icon":"frame","mappings":[],"widgets":[{"widgetId":"1100","type":"Text","label":"Außensteckdose","icon":"poweroutlet","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnRelayVisAussen","state":"OPEN","editable":false,"type":"Contact","name":"lcnRelayVisAussen","label":"Außensteckdose","category":"poweroutlet","tags":[],"groupNames":["gLcn"]},"widgets":[]},{"widgetId":"1101","type":"Switch","label":"Außensteckdose","icon":"poweroutlet","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnRelayAussen","state":"OFF","editable":false,"type":"Switch","name":"lcnRelayAussen","label":"Außensteckdose","category":"poweroutlet","tags":["Switchable"],"groupNames":["gLcn"]},"widgets":[]},{"widgetId":"1102","type":"Switch","label":"Außenlichter Terrassen","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnLightCommand11A_1","state":"NULL","editable":false,"type":"Switch","name":"lcnLightCommand11A_1","label":"Außenlichter Terrassen","category":"switch","tags":[],"groupNames":[]},"widgets":[]}]},{"widgetId":"12","type":"Frame","label":"Musiccast Wohnzimmer","icon":"frame","mappings":[],"widgets":[{"widgetId":"1200","type":"Switch","label":"Power [ON]","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/Yamaha_Power","state":"ON","stateDescription":{"pattern":"%s","readOnly":false,"options":[]},"editable":false,"type":"Switch","name":"Yamaha_Power","label":"Power","category":"switch","tags":[],"groupNames":[]},"widgets":[]},{"widgetId":"1201","type":"Switch","label":"Mute [OFF]","icon":"soundvolume_mute","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/Yamaha_Mute","state":"OFF","stateDescription":{"pattern":"%s","readOnly":false,"options":[]},"editable":false,"type":"Switch","name":"Yamaha_Mute","label":"Mute","category":"soundvolume_mute","tags":[],"groupNames":[]},"widgets":[]},{"widgetId":"1202","type":"Slider","label":"Volume [41.0 %]","icon":"soundvolume","mappings":[],"switchSupport":false,"sendFrequency":0,"item":{"link":"https://myopenhab.org/rest/items/Yamaha_Volume","state":"41","stateDescription":{"pattern":"%.1f %%","readOnly":false,"options":[]},"editable":false,"type":"Dimmer","name":"Yamaha_Volume","label":"Volume","category":"soundvolume","tags":[],"groupNames":[]},"widgets":[]}]},{"widgetId":"13","type":"Frame","label":"Jalousien EG","icon":"frame","mappings":[],"widgets":[{"widgetId":"1300","type":"Switch","label":"EGJalousien","icon":"rollershutter","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/EGJalousien","state":"NULL","editable":false,"type":"Rollershutter","name":"EGJalousien","tags":[],"groupNames":[]},"widgets":[]},{"widgetId":"1301","type":"Switch","label":"EGJalousienSued","icon":"rollershutter","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/EGJalousienSued","state":"NULL","editable":false,"type":"Rollershutter","name":"EGJalousienSued","tags":[],"groupNames":[]},"widgets":[]},{"widgetId":"1302","type":"Group","label":"EG Süd","icon":"rollershutter","mappings":[],"item":{"members":[],"link":"https://myopenhab.org/rest/items/gEGJalousienSued","state":"NULL","editable":false,"type":"Group","name":"gEGJalousienSued","label":"EG Jalousien Sued","tags":[],"groupNames":["gEGJalousien","gJalousienSued"]},"linkedPage":{"id":"1302","title":"EG Süd","icon":"rollershutter","link":"https://myopenhab.org/rest/sitemaps/myHome/1302","leaf":true,"timeout":false},"widgets":[]},{"widgetId":"1303","type":"Switch","label":"EGJalousienWest","icon":"rollershutter","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/EGJalousienWest","state":"NULL","editable":false,"type":"Rollershutter","name":"EGJalousienWest","tags":[],"groupNames":[]},"widgets":[]},{"widgetId":"1304","type":"Group","label":"EG West","icon":"rollershutter","mappings":[],"item":{"members":[],"link":"https://myopenhab.org/rest/items/gEGJalousienWest","state":"NULL","editable":false,"type":"Group","name":"gEGJalousienWest","label":"EG Jalousien West","tags":[],"groupNames":["gEGJalousien","gJalousienWest"]},"linkedPage":{"id":"1304","title":"EG West","icon":"rollershutter","link":"https://myopenhab.org/rest/sitemaps/myHome/1304","leaf":true,"timeout":false},"widgets":[]}]},{"widgetId":"14","type":"Frame","label":"Jalousie 1. OG","icon":"frame","mappings":[],"widgets":[{"widgetId":"1400","type":"Switch","label":"KiZ Jalousien","icon":"rollershutter","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/KZJalousien","state":"NULL","editable":false,"type":"Rollershutter","name":"KZJalousien","tags":[],"groupNames":[]},"widgets":[]},{"widgetId":"1401","type":"Group","label":"KiZ","icon":"rollershutter","mappings":[],"item":{"members":[],"link":"https://myopenhab.org/rest/items/gKZJalousien","state":"NULL","editable":false,"type":"Group","name":"gKZJalousien","label":"KiZ Jalousien","tags":[],"groupNames":["gHausJalousien"]},"linkedPage":{"id":"1401","title":"KiZ","icon":"rollershutter","link":"https://myopenhab.org/rest/sitemaps/myHome/1401","leaf":true,"timeout":false},"widgets":[]},{"widgetId":"1402","type":"Switch","label":"Jalousie SZ","icon":"rollershutter","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnJalousieSZ","state":"0.0","editable":false,"type":"Rollershutter","name":"lcnJalousieSZ","label":"Jalousie SZ","tags":[],"groupNames":["gSZ","g1OJalousien","gHausJalousie","gJalousienWest","gLcn"]},"widgets":[]},{"widgetId":"1403","type":"Switch","label":"Jalousie Bad","icon":"rollershutter","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/lcnJalousieBad","state":"NULL","editable":false,"type":"Rollershutter","name":"lcnJalousieBad","label":"Jalousie Bad","tags":[],"groupNames":["gBad","g1OJalousien","gHausJalousie","gLcn"]},"widgets":[]}]},{"widgetId":"15","type":"Frame","label":"Heizung","icon":"frame","mappings":[],"widgets":[{"widgetId":"1500","type":"Switch","label":"Fernsteuerung","icon":"switch","mappings":[{"command":"0","label":"Overwrite"},{"command":"1","label":"Kalender"},{"command":"2","label":"Automatik"}],"item":{"link":"https://myopenhab.org/rest/items/Automatik","state":"1","editable":false,"type":"String","name":"Automatik","tags":[],"groupNames":[]},"widgets":[]},{"widgetId":"1501","type":"Text","label":"Aussentemperatur [1.0 °C]","icon":"temperature","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/TempAussen","state":"1.0","stateDescription":{"pattern":"%.1f °C","readOnly":false,"options":[]},"editable":false,"type":"Number","name":"TempAussen","label":"Aussentemperatur","category":"temperature","tags":[],"groupNames":["gOnewire"]},"widgets":[]},{"widgetId":"1502","type":"Text","label":"Fernverrriegelt? [Nein]","icon":"text","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/oneWireSwitch1","state":"OFF","stateDescription":{"pattern":"%s","readOnly":false,"options":[]},"editable":false,"type":"Switch","name":"oneWireSwitch1","label":"OneWireSwitch 1","tags":[],"groupNames":["gOnewire"]},"widgets":[]},{"widgetId":"1503","type":"Text","label":"NewBindingTest","icon":"text","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/DigitalIOForHeating052CED31000000_DigitalIO0","state":"NULL","stateDescription":{"readOnly":true,"options":[]},"editable":false,"type":"Switch","name":"DigitalIOForHeating052CED31000000_DigitalIO0","label":"Digital I/O 0","tags":[],"groupNames":[]},"widgets":[]},{"widgetId":"1504","type":"Text","label":"Google Kalender Status [-]","icon":"text","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/FernsteuerungHeizung","state":"NULL","editable":false,"type":"Switch","name":"FernsteuerungHeizung","tags":[],"groupNames":[]},"widgets":[]}]},{"widgetId":"16","type":"Frame","label":"Abwesenheit","icon":"frame","mappings":[],"widgets":[{"widgetId":"1600","type":"Switch","label":"Abwesenheitssimulation openhab","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/PresenceSimulation","state":"NULL","editable":false,"type":"Switch","name":"PresenceSimulation","label":"Abwesenheitssimulation openhab","tags":[],"groupNames":[]},"widgets":[]}]},{"widgetId":"17","type":"Frame","label":"Osram Equipment","icon":"frame","mappings":[],"widgets":[{"widgetId":"1700","type":"Switch","label":"Osram Indoor Plug 01","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/OSRAMPlug01_Switch","state":"NULL","editable":false,"type":"Switch","name":"OSRAMPlug01_Switch","label":"Osram Indoor Plug 01","tags":[],"groupNames":["gRemoteItems"]},"widgets":[]},{"widgetId":"1701","type":"Switch","label":"Osram Bulb 01","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/OSRAMClassicA60WClearLIGHTIFY_Switch","state":"NULL","editable":false,"type":"Switch","name":"OSRAMClassicA60WClearLIGHTIFY_Switch","label":"Osram Bulb 01","tags":[],"groupNames":["gRemoteItems"]},"widgets":[]},{"widgetId":"1702","type":"Switch","label":"Osram Outdoor Plug 01","icon":"switch","mappings":[],"item":{"link":"https://myopenhab.org/rest/items/OSRAMPlugOutdoor_Switch","state":"NULL","editable":false,"type":"Switch","name":"OSRAMPlugOutdoor_Switch","label":"Osram Outdoor Plug 01","tags":[],"groupNames":["gRemoteItems"]},"widgets":[]},{"widgetId":"1703","type":"Slider","label":"Osram Bulb 01 Dimmer","icon":"slider","mappings":[],"switchSupport":false,"sendFrequency":0,"item":{"link":"https://myopenhab.org/rest/items/OSRAMClassicA60WClearLIGHTIFY_LevelControl","state":"5","editable":false,"type":"Dimmer","name":"OSRAMClassicA60WClearLIGHTIFY_LevelControl","label":"Osram Bulb 01 Dimmer","tags":[],"groupNames":["gRemoteItems"]},"widgets":[]}]}]}
""".data(using: .utf8)!
        do {
            let codingData = try decoder.decode(OpenHABSitemapPage.CodingData.self, from: json)
            XCTAssert(codingData.leaf == false, "OpenHABSitemapPage properly parsed")
            XCTAssert(codingData.widgets?[0].widgetId == "00", "widget properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testJSONSitemapPage2() {
        let json = """
{
  "id": "grafana",
  "title": "grafana",
  "link": "https://myopenhab.org/rest/sitemaps/grafana/grafana",
  "leaf": false,
  "timeout": false,
  "widgets": [
    {
      "widgetId": "00",
      "type": "Frame",
      "label": "Date",
      "icon": "frame",
      "mappings": [],
      "widgets": [
        {
          "widgetId": "0000",
          "type": "Text",
          "label": "Date",
          "icon": "text",
          "mappings": [],
          "widgets": []
        },
        {
          "widgetId": "0001",
          "type": "Switch",
          "label": "bliblablu-bliblablu-bliblablu-bliblablu-bliblablu [Kellertest]",
          "icon": "switch",
          "mappings": [],
          "item": {
            "link": "https://myopenhab.org/rest/items/lcnLightSwitch5_1",
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
      ]
    },
    {
      "widgetId": "01",
      "type": "Frame",
      "label": "Gas",
      "icon": "frame",
      "mappings": [],
      "widgets": [
        {
          "widgetId": "0100",
          "type": "Setpoint",
          "label": "Pauli Thermostat [- °C]",
          "icon": "number",
          "mappings": [],
          "minValue": 4.5,
          "maxValue": 26,
          "step": 0.5,
          "item": {
            "link": "https://myopenhab.org/rest/items/HMCCRTDNLinks_4_SetTemperature",
            "state": "NULL",
            "editable": false,
            "type": "Number:Temperature",
            "name": "HMCCRTDNLinks_4_SetTemperature",
            "label": "Set Temperature",
            "tags": [],
            "groupNames": []
          },
          "widgets": []
        },
        {
          "widgetId": "0101",
          "type": "Image",
          "label": "",
          "icon": "image",
          "mappings": [],
          "url": "https://myopenhab.org/proxy?sitemap=grafana.sitemap&widgetId=0101",
          "widgets": []
        },
        {
          "widgetId": "0102",
          "type": "Setpoint",
          "label": "bliblablu-bliblablu-bliblablu-bliblablu-bliblablu",
          "icon": "setpoint",
          "mappings": [],
          "minValue": 0,
          "maxValue": 100,
          "step": 5,
          "item": {
            "link": "https://myopenhab.org/rest/items/OSRAMClassicA60WClearLIGHTIFY_LevelControl",
            "state": "5",
            "editable": false,
            "type": "Dimmer",
            "name": "OSRAMClassicA60WClearLIGHTIFY_LevelControl",
            "label": "Osram Bulb 01 Dimmer",
            "tags": [],
            "groupNames": [
              "gRemoteItems"
            ]
          },
          "widgets": []
        }
      ]
    },
    {
      "widgetId": "02",
      "type": "Frame",
      "label": "Map",
      "icon": "frame",
      "mappings": [],
      "widgets": [
        {
          "widgetId": "0200",
          "type": "Mapview",
          "label": "Demo_Location",
          "icon": "mapview",
          "mappings": [],
          "height": 0,
          "widgets": []
        }
      ]
    },
    {
      "widgetId": "03",
      "type": "Frame",
      "label": "Test",
      "icon": "frame",
      "mappings": [],
      "widgets": [
        {
          "widgetId": "0300",
          "type": "Group",
          "label": "Whats ON",
          "icon": "info",
          "mappings": [],
          "item": {
            "members": [],
            "link": "https://myopenhab.org/rest/items/gStateON",
            "state": "NULL",
            "editable": false,
            "type": "Group",
            "name": "gStateON",
            "label": "Whats ON",
            "category": "info",
            "tags": [],
            "groupNames": []
          },
          "widgets": []
        },
        {
          "widgetId": "0305",
          "type": "Mapview",
          "label": "Location [-°N -°E -m]",
          "icon": "mapview",
          "mappings": [],
          "height": 0,
          "item": {
            "link": "https://myopenhab.org/rest/items/GPSTrackerTi_Location",
            "state": "NULL",
            "stateDescription": {
              "pattern": "%2$s°N %3$s°E %1$sm",
              "readOnly": true,
              "options": []
            },
            "editable": false,
            "type": "Location",
            "name": "GPSTrackerTi_Location",
            "label": "Location",
            "tags": [],
            "groupNames": []
          },
          "widgets": []
        },
        {
          "widgetId": "0306",
          "type": "Text",
          "label": "Battery Level [68 %]",
          "icon": "battery",
          "mappings": [],
          "item": {
            "link": "https://myopenhab.org/rest/items/GPSTrackerTi_BatteryLevel",
            "state": "68.0",
            "stateDescription": {
              "minimum": 0,
              "maximum": 100,
              "step": 1,
              "pattern": "%.0f %%",
              "readOnly": true,
              "options": []
            },
            "editable": false,
            "type": "Number",
            "name": "GPSTrackerTi_BatteryLevel",
            "label": "Battery Level",
            "category": "Battery",
            "tags": [],
            "groupNames": [
              "gGPSTracker"
            ]
          },
          "widgets": []
        },
        {
          "widgetId": "0307",
          "type": "Text",
          "label": "Location [-°N -°E -m]",
          "icon": "text",
          "mappings": [],
          "item": {
            "link": "https://myopenhab.org/rest/items/GPSTrackerTi_Location",
            "state": "NULL",
            "stateDescription": {
              "pattern": "%2$s°N %3$s°E %1$sm",
              "readOnly": true,
              "options": []
            },
            "editable": false,
            "type": "Location",
            "name": "GPSTrackerTi_Location",
            "label": "Location",
            "tags": [],
            "groupNames": []
          },
          "widgets": []
        },
        {
          "widgetId": "0308",
          "type": "Text",
          "label": "Accuracy [- -]",
          "icon": "number",
          "mappings": [],
          "item": {
            "link": "https://myopenhab.org/rest/items/GPSTrackerTi_Accuracy",
            "state": "NULL",
            "stateDescription": {
              "pattern": "%d %unit%",
              "readOnly": true,
              "options": []
            },
            "editable": false,
            "type": "Number:Length",
            "name": "GPSTrackerTi_Accuracy",
            "label": "Accuracy",
            "tags": [],
            "groupNames": []
          },
          "widgets": []
        },
        {
          "widgetId": "0309",
          "type": "Setpoint",
          "label": "Min/Max/Step/Int [- °C]",
          "icon": "number",
          "mappings": [],
          "item": {
            "link": "https://myopenhab.org/rest/items/Wassertemperatur_Soll_Setpoint",
            "state": "NULL",
            "editable": false,
            "type": "Number",
            "name": "Wassertemperatur_Soll_Setpoint",
            "tags": [],
            "groupNames": []
          },
          "widgets": []
        },
        {
          "widgetId": "0310",
          "type": "Setpoint",
          "label": "Warne nach [- Min]",
          "icon": "shield",
          "mappings": [],
          "minValue": 0,
          "maxValue": 1440,
          "step": 10,
          "item": {
            "link": "https://myopenhab.org/rest/items/Wassertemperatur_Soll_Setpoint",
            "state": "NULL",
            "editable": false,
            "type": "Number",
            "name": "Wassertemperatur_Soll_Setpoint",
            "tags": [],
            "groupNames": []
          },
          "widgets": []
        },
        {
          "widgetId": "0311",
          "type": "Text",
          "label": "Status [3.8 °C]",
          "icon": "house",
          "valuecolor": "red",
          "mappings": [],
          "item": {
            "link": "https://myopenhab.org/rest/items/TempAussen",
            "state": "3.8125",
            "stateDescription": {
              "pattern": "%.1f °C",
              "readOnly": false,
              "options": []
            },
            "editable": false,
            "type": "Number",
            "name": "TempAussen",
            "label": "Aussentemperatur",
            "category": "temperature",
            "tags": [],
            "groupNames": [
              "gOnewire"
            ]
          },
          "widgets": []
        }
      ]
    },
    {
      "widgetId": "05",
      "type": "Frame",
      "label": "test",
      "icon": "frame",
      "mappings": [],
      "widgets": [
        {
          "widgetId": "0500",
          "type": "Text",
          "label": "MySensor [- -]",
          "icon": "number",
          "mappings": [],
          "item": {
            "link": "https://myopenhab.org/rest/items/MySensor",
            "state": "NULL",
            "stateDescription": {
              "pattern": "%.1f %unit%",
              "readOnly": false,
              "options": []
            },
            "editable": false,
            "type": "Number:Temperature",
            "name": "MySensor",
            "label": "MySensor",
            "tags": [],
            "groupNames": []
          },
          "widgets": []
        },
        {
          "widgetId": "0501",
          "type": "Switch",
          "label": "gKellerLicht",
          "icon": "switch",
          "mappings": [],
          "item": {
            "members": [],
            "link": "https://myopenhab.org/rest/items/gKellerLicht",
            "state": "NULL",
            "editable": false,
            "type": "Group",
            "name": "gKellerLicht",
            "tags": [],
            "groupNames": []
          },
          "widgets": []
        },
        {
          "widgetId": "0507",
          "type": "Text",
          "label": "Tim's iPhone: Last Seen [21:23:59]",
          "icon": "text",
          "mappings": [],
          "item": {
            "link": "https://myopenhab.org/rest/items/unifiIPhoneTimLastSeen",
            "state": "2019-03-12T21:23:59.000+0100",
            "stateDescription": {
              "pattern": "%1$tH:%1$tM:%1$tS",
              "readOnly": true,
              "options": []
            },
            "editable": false,
            "type": "DateTime",
            "name": "unifiIPhoneTimLastSeen",
            "label": "Tim's iPhone: Last Seen",
            "tags": [],
            "groupNames": [
              "gUnifi"
            ]
          },
          "widgets": []
        },
        {
          "widgetId": "0508",
          "type": "Text",
          "label": "MoonPhase [Waxing crescent]",
          "icon": "text",
          "mappings": [],
          "item": {
            "link": "https://myopenhab.org/rest/items/MoonPhase",
            "state": "WAXING_CRESCENT",
            "stateDescription": {
              "pattern": "%s",
              "readOnly": true,
              "options": [
                {
                  "value": "NEW",
                  "label": "New moon"
                },
                {
                  "value": "WAXING_CRESCENT",
                  "label": "Waxing crescent"
                },
                {
                  "value": "FIRST_QUARTER",
                  "label": "First quarter"
                },
                {
                  "value": "WAXING_GIBBOUS",
                  "label": "Waxing gibbous"
                },
                {
                  "value": "FULL",
                  "label": "Full moon"
                },
                {
                  "value": "WANING_GIBBOUS",
                  "label": "Waning gibbous"
                },
                {
                  "value": "THIRD_QUARTER",
                  "label": "Third quarter"
                },
                {
                  "value": "WANING_CRESCENT",
                  "label": "Waning crescent"
                }
              ]
            },
            "editable": false,
            "type": "String",
            "name": "MoonPhase",
            "label": "MoonPhase",
            "tags": [],
            "groupNames": []
          },
          "widgets": []
        }
      ]
    }
  ]
}
""".data(using: .utf8)!
        do {
            let codingData = try decoder.decode(OpenHABSitemapPage.CodingData.self, from: json)
            XCTAssert(codingData.leaf == false, "OpenHABSitemapPage properly parsed")
            XCTAssert(codingData.widgets?[0].widgetId == "00", "widget properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

func testLinkedSitemapPageForCharts() {
    let json = """
{"linkedPage":{"id":"0000","title":"Current Temperature [23.0 °C]","icon":"temperature","link":"https://192.168.2.15:8444/rest/sitemaps/charts/0000","leaf":true,"timeout":false,"widgets":[{"widgetId":"000000","type":"Chart","label":"Current Temperature [23.0 °C]","icon":"temperature","mappings":[],"refresh":600,"period":"h","item":{"link":"https://192.168.2.15:8444/rest/items/CometDECT2PauliRechts_CurrentTemperature","state":"23.0 °C","stateDescription":{"pattern":"%.1f %unit%","readOnly":true,"options":[]},"editable":false,"type":"Number:Temperature","name":"CometDECT2PauliRechts_CurrentTemperature","label":"Current Temperature","category":"Temperature","tags":[],"groupNames":[]},"widgets":[]},{"widgetId":"000001","type":"Chart","label":"Current Temperature [23.0 °C]","icon":"temperature","mappings":[],"refresh":600,"period":"d","item":{"link":"https://192.168.2.15:8444/rest/items/CometDECT2PauliRechts_CurrentTemperature","state":"23.0 °C","stateDescription":{"pattern":"%.1f %unit%","readOnly":true,"options":[]},"editable":false,"type":"Number:Temperature","name":"CometDECT2PauliRechts_CurrentTemperature","label":"Current Temperature","category":"Temperature","tags":[],"groupNames":[]},"widgets":[]}]},"widgets":[]}]}]}}
""".data(using: .utf8)!
    do {
        let codingData = try decoder.decode(OpenHABSitemapPage.CodingData.self, from: json)
        XCTAssert(codingData.widgets[0].type == "false", "OpenHABSitemapPage properly parsed")
//        XCTAssert(codingData.openHABSitemapPage. widgets[0].type == "Frame", "")
//        XCTAssert(.widgets[0].linkedPage?.pageId == "0000", "widget properly parsed")
    } catch {
        XCTFail("Whoops, an error occured: \(error)")
    }
    }

    func testLinkedSitemapPageForCharts2() {
        let json = """
{"linkedPage": {
    "id": "0000",
    "title": "Current Temperature [23.0 °C]",
    "icon": "temperature",
    "link": "https://192.168.2.15:8444/rest/sitemaps/charts/0000",
    "leaf": true,
    "timeout": false,
    "widgets": [{
    "widgetId": "000000",
    "type": "Chart",
    "label": "Current Temperature [23.0 °C]",
    "icon": "temperature",
    "mappings": [],
    "refresh": 600,
    "period": "h",
    "item": {
    "link": "https://192.168.2.15:8444/rest/items/CometDECT2PauliRechts_CurrentTemperature",
    "state": "23.0 °C",
    "stateDescription": {
    "pattern": "%.1f %unit%",
    "readOnly": true,
    "options": []
    },
    "editable": false,
    "type": "Number:Temperature",
    "name": "CometDECT2PauliRechts_CurrentTemperature",
    "label": "Current Temperature",
    "category": "Temperature",
    "tags": [],
    "groupNames": []
    },
    "widgets": []
    }, {
    "widgetId": "000001",
    "type": "Chart",
    "label": "Current Temperature [23.0 °C]",
    "icon": "temperature",
    "mappings": [],
    "refresh": 600,
    "period": "d",
    "item": {
    "link": "https://192.168.2.15:8444/rest/items/CometDECT2PauliRechts_CurrentTemperature",
    "state": "23.0 °C",
    "stateDescription": {
    "pattern": "%.1f %unit%",
    "readOnly": true,
    "options": []
    },
    "editable": false,
    "type": "Number:Temperature",
    "name": "CometDECT2PauliRechts_CurrentTemperature",
    "label": "Current Temperature",
    "category": "Temperature",
    "tags": [],
    "groupNames": []
    },
    "widgets": []
    }]
    }
""".data(using: .utf8)!
        do {
            let codingData = try decoder.decode(OpenHABSitemapPage.CodingData.self, from: json)
            XCTAssert(codingData. .type == "false", "OpenHABSitemapPage properly parsed")
            //        XCTAssert(codingData.openHABSitemapPage. widgets[0].type == "Frame", "")
            //        XCTAssert(.widgets[0].linkedPage?.pageId == "0000", "widget properly parsed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    func testEndPoints() {
       let urlc = Endpoint.icon(rootUrl: "http://192.169.2.1",
                             version: 2,
                             icon: "switch",
                             value: "OFF",
                             iconType: .svg ).url
        XCTAssert(urlc == URL(string: "http://192.169.2.1/icon/switch?state=OFF&format=SVG"), "Check endpoint creation")
    }

}
