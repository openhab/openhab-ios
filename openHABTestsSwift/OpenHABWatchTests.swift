// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

@testable import openHAB
import XCTest

class OpenHABWatchTests: XCTestCase {
    let jsonInput = """
    {
      "name": "watch",
      "label": "Watch",
      "link": "https://192.168.0.1:8080/rest/sitemaps/watch",
      "homepage": {
        "id": "watch",
        "title": "Watch",
        "link": "https://192.168.0.1:8080/rest/sitemaps/watch/watch",
        "leaf": false,
        "timeout": false,
        "widgets": [
          {
            "widgetId": "00",
            "type": "Switch",
            "label": "Haustür",
            "icon": "lock",
            "mappings": [
            ],
            "item": {
              "link": "https://192.168.0.1:8080/rest/items/KeyMatic_Open",
              "state": "OFF",
              "stateDescription": {
                "readOnly": false,
                "options": [
                ]
              },
              "editable": false,
              "type": "Switch",
              "name": "KeyMatic_Open",
              "label": "Haustuer",
              "category": "lock",
              "tags": [
              ],
              "groupNames": [
              ]
            },
            "widgets": [
            ]
          },
          {
            "widgetId": "01",
            "type": "Switch",
            "label": "Garagentor",
            "icon": "garage",
            "mappings": [
            ],
            "item": {
              "link": "https://192.168.0.1:8080/rest/items/Garagentor_Taster",
              "state": "OFF",
              "stateDescription": {
                "readOnly": false,
                "options": [
                ]
              },
              "editable": false,
              "type": "Switch",
              "name": "Garagentor_Taster",
              "label": "Garagentor",
              "category": "garage",
              "tags": [
              ],
              "groupNames": [
              ]
            },
            "widgets": [
            ]
          },
          {
            "widgetId": "02",
            "type": "Switch",
            "label": "Garagentür [verriegelt]",
            "icon": "lock",
            "mappings": [
            ],
            "item": {
              "link": "https://192.168.0.1:8080/rest/items/KeyMatic_Garage_State",
              "state": "OFF",
              "transformedState": "verriegelt",
              "stateDescription": {
                "pattern": "",
                "readOnly": false,
                "options": [
                ]
              },
              "editable": false,
              "type": "Switch",
              "name": "KeyMatic_Garage_State",
              "label": "Garagentuer entriegelt",
              "category": "lock",
              "tags": [
              ],
              "groupNames": [
              ]
            },
            "widgets": [
            ]
          },
          {
            "widgetId": "03",
            "type": "Switch",
            "label": "Küchenlicht",
            "icon": "switch",
            "mappings": [
            ],
            "item": {
              "link": "https://192.168.0.1:8080/rest/items/Licht_EG_Kueche",
              "state": "OFF",
              "stateDescription": {
                "readOnly": false,
                "options": [
                ]
              },
              "editable": false,
              "type": "Switch",
              "name": "Licht_EG_Kueche",
              "label": "Kuechenlampe",
              "tags": [
              ],
              "groupNames": [
                "gEG",
                "Lichter",
                "Simulation"
              ]
            },
            "widgets": [
            ]
          },
          {
            "widgetId": "04",
            "type": "Switch",
            "label": "Bewässerung",
            "icon": "switch",
            "mappings": [
            ],
            "item": {
              "link": "https://192.168.0.1:8080/rest/items/HK_Bewaesserung",
              "state": "OFF",
              "editable": false,
              "type": "Switch",
              "name": "HK_Bewaesserung",
              "label": "Bewaesserung",
              "tags": [
                "Lighting"
              ],
              "groupNames": [
              ]
            },
            "widgets": [
            ]
          },
          {
            "widgetId": "05",
            "type": "Switch",
            "label": "Pumpe",
            "icon": "switch",
            "mappings": [
            ],
            "item": {
              "link": "https://192.168.0.1:8080/rest/items/Pumpe_Garten",
              "state": "OFF",
              "stateDescription": {
                "readOnly": false,
                "options": [
                ]
              },
              "editable": false,
              "type": "Switch",
              "name": "Pumpe_Garten",
              "label": "Pumpe",
              "tags": [
              ],
              "groupNames": [
                "Garten"
              ]
            },
            "widgets": [
            ]
          }
        ]
      }
    }
    """

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
        let data = Data(jsonInput.utf8)
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)
            guard let jsonDict: NSDictionary = json as? NSDictionary else {
                XCTFail("Not able to parse")
                return
            }
            let homepageDict = jsonDict.object(forKey: "homepage") as! NSDictionary
            if homepageDict.isEmpty {
                XCTFail("Not finding homepage")
                return
            }
            let widgetsDict = homepageDict.object(forKey: "widgets") as! NSMutableArray
            if widgetsDict.isEmpty {
                XCTFail("widgets not found")
                return
            }
        } catch {
            XCTFail("Failed parsing")
        }
    }

    // Parsing to [Item]
    func testSiteMapForWatchParsingWithDecodable() {
        var items: [Item] = []

        let data = Data(jsonInput.utf8)
        do {
            let codingData = try decoder.decode(OpenHABSitemap.CodingData.self, from: data)
            XCTAssert(codingData.label == "Watch", "OpenHABSitemap properly parsed")
            XCTAssert(codingData.page.widgets?[0].type == "Switch", "widget properly parsed")
            let widgets = try require(codingData.page.widgets)
            items = widgets.compactMap { Item(with: $0.item) }
            XCTAssert(items[0].name == "KeyMatic_Open", "Construction of items failed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    // Decodable parsing to Frame
    func testSiteMapForWatchParsingWithDecodabletoFrame() {
        var frame: Frame

        let data = Data(jsonInput.utf8)
        do {
            let codingData = try decoder.decode(OpenHABSitemap.CodingData.self, from: data)
            frame = Frame(with: codingData)!
            XCTAssert(frame.items[0].name == "KeyMatic_Open", "Parsing of Frame failed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }

    // Decodable parsing to Sitemap
    func testSiteMapForWatchParsingWithDecodabletoSitemap() {
        let data = Data(jsonInput.utf8)
        do {
            let codingData = try decoder.decode(OpenHABSitemap.CodingData.self, from: data)
            let sitemap = try require(Sitemap(with: codingData))
            XCTAssert(sitemap.frames[0].items[0].name == "KeyMatic_Open", "Parsing of Frame failed")
        } catch {
            XCTFail("Whoops, an error occured: \(error)")
        }
    }
}
