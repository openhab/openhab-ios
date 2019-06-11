//
//  OpenHABWatchTests.swift
//  openHABTestsSwift
//
//  Created by Tim Müller-Seydlitz on 09.06.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import XCTest

class OpenHABWatchTests: XCTestCase {

    let decoder = JSONDecoder()

    override func setUp() {
        super.setUp()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
// Pre-Decodable JSON parsing
    func testSiteMapForWatchParsing() {
        let jsonInput = """
{
  "name": "watch",
  "label": "watch",
  "link": "https://192.168.2.15:8444/rest/sitemaps/watch",
  "homepage": {
    "id": "testing",
    "title": "watch",
    "link": "https://192.168.2.15:8444/rest/sitemaps/testing/testing",
    "leaf": false,
    "timeout": false,
    "widgets": [{
      "widgetId": "00",
      "type": "Frame",
      "label": "Gas",
      "icon": "frame",
      "mappings": [],
      "widgets": [{
        "widgetId": "0000",
        "type": "Switch",
        "label": "Licht Oberlicht",
        "icon": "switch",
        "mappings": [],
        "item": {
          "link": "https://192.168.2.15:8444/rest/items/lcnLightSwitch14_1",
          "state": "OFF",
          "editable": false,
          "type": "Switch",
          "name": "lcnLightSwitch14_1",
          "label": "Licht Oberlicht",
          "tags": ["Lighting"],
          "groupNames": ["G_PresenceSimulation", "gLcn"]
        },
        "widgets": []
      }]
    }]
  }
}
"""
        let data = Data(jsonInput.utf8)
        do {
            // swiftlint:disable empty_count

            let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)
            guard let jsonDict: NSDictionary = json as? NSDictionary else {
                XCTFail("Not able to parse")
                return
            }
            let homepageDict = jsonDict.object(forKey: "homepage") as! NSDictionary
            if homepageDict.count == 0 {
                XCTFail("Not finding homepage")
                return
            }
            let widgetsDict = homepageDict.object(forKey: "widgets") as! NSMutableArray
            if widgetsDict.count == 0 {
                XCTFail("widgets not found")
                return
            }
            // swiftlint:enable empty_count

        } catch {
            XCTFail("Failed parsing")
        }
    }
// Parsing to [Item]
    func testSiteMapForWatchParsingWithDecodable() {
        let jsonInput = """
{"name":"watch","label":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch","homepage":{"id":"watch","title":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch/watch","leaf":false,"timeout":false,"widgets":[{"widgetId":"00","type":"Frame","label":"Ground floor","icon":"frame","mappings":[],"widgets":[{"widgetId":"0000","type":"Switch","label":"Licht Oberlicht","icon":"switch","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch14_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch14_1","label":"Licht Oberlicht","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0001","type":"Switch","label":"Licht Keller WC Decke","icon":"switch","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch6_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch6_1","label":"Licht Keller WC Decke","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]}]}]}}
"""
        var items: [Item] = []

        let data = Data(jsonInput.utf8)
        do {
            let codingData = try decoder.decode(OpenHABSitemap.CodingData.self, from: data)
            XCTAssert(codingData.label == "watch", "OpenHABSitemap properly parsed")
            XCTAssert(codingData.homepage.widgets?[0].widgets[0].type == "Switch", "widget properly parsed")
            let widgets = try require(codingData.homepage.widgets?[0].widgets)
            items = widgets.compactMap { Item.init(with: $0.item) }
            XCTAssert(items[0].name == "lcnLightSwitch14_1", "Construction of items failed" )
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }

    }

// Decodable parsing to Frame
    func testSiteMapForWatchParsingWithDecodabletoFrame() {
        let jsonInput = """
{"name":"watch","label":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch","homepage":{"id":"watch","title":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch/watch","leaf":false,"timeout":false,"widgets":[{"widgetId":"00","type":"Frame","label":"Ground floor","icon":"frame","mappings":[],"widgets":[{"widgetId":"0000","type":"Switch","label":"Licht Oberlicht","icon":"switch","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch14_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch14_1","label":"Licht Oberlicht","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0001","type":"Switch","label":"Licht Keller WC Decke","icon":"switch","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch6_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch6_1","label":"Licht Keller WC Decke","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]}]}]}}
"""
        var frame: Frame

        let data = Data(jsonInput.utf8)
        do {
            let codingData = try decoder.decode(OpenHABSitemap.CodingData.self, from: data)
            frame = Frame.init(with: codingData)!
            XCTAssert(frame.items[0].name == "lcnLightSwitch14_1", "Parsing of Frame failed" )
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

// Decodable parsing to Sitemap
func testSiteMapForWatchParsingWithDecodabletoSitemap() {
    let jsonInput = """
{"name":"watch","label":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch","homepage":{"id":"watch","title":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch/watch","leaf":false,"timeout":false,"widgets":[{"widgetId":"00","type":"Frame","label":"Ground floor","icon":"frame","mappings":[],"widgets":[{"widgetId":"0000","type":"Switch","label":"Licht Oberlicht","icon":"switch","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch14_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch14_1","label":"Licht Oberlicht","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]},{"widgetId":"0001","type":"Switch","label":"Licht Keller WC Decke","icon":"switch","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch6_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch6_1","label":"Licht Keller WC Decke","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]}]}]}}
"""

    let data = Data(jsonInput.utf8)
    do {
        let codingData = try decoder.decode(OpenHABSitemap.CodingData.self, from: data)
        let sitemap = try require(Sitemap.init(with: codingData))
        XCTAssert(sitemap.frames[0].items[0].name == "lcnLightSwitch14_1", "Parsing of Frame failed" )
    } catch {
        XCTFail("Whoops, an error occured: \(error)")
    }
}
}
