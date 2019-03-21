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
        //decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

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
        [{"_id":"5c4229b41cd87d98382869da","message":"Light Küche was changed","__v":0,"created":"2019-01-18T19:32:04.648Z"},{"_id":"5c4229b41cd87d98382869da","message":"Light Küche was changed","__v":0,"created":"2019-01-18T19:32:04.648Z"}]
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

    func testHexString() {
        let iPhoneData: Data = "Tim iPhone".data(using: .utf8)!
        let hexWithReduce = iPhoneData.reduce("", {$0 + String(format: "%02X", $1)})
        XCTAssert (hexWithReduce == "54696D206950686F6E65", "hex properly calculated with reduce")
    }
}
