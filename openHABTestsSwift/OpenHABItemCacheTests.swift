// Copyright (c) 2010-2022 Contributors to the openHAB project
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
import XCTest

class OpenHABItemCacheTests: XCTestCase {
    static let ITEMS_URL = "/rest/items?"
    let instance = OpenHABItemCache.instance

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAppendingPathComponent() throws {
        let url = URL(string: "http://demo.openhab.org:8080/rest/items/DemoSwitch")!.appendingPathComponent("/state")
        XCTAssertEqual(url.absoluteString, "http://demo.openhab.org:8080/rest/items/DemoSwitch/state")
    }

    func testGetURL() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        Preferences.localUrl = "http://192.168.0.1:8080"
        Preferences.remoteUrl = "http://myopenhab.org:8080"
        Preferences.demomode = false

        var url = instance.getURL()
        XCTAssert(instance.lastUrlConnected == OpenHABItemCache.URL_LOCAL)
        var expected = Preferences.localUrl + OpenHABItemCacheTests.ITEMS_URL
        var result = url?.absoluteString ?? ""
        XCTAssert(expected == result)

        instance.localUrlFailed = true

        url = instance.getURL()
        XCTAssert(instance.lastUrlConnected == OpenHABItemCache.URL_REMOTE)
        expected = Preferences.remoteUrl + OpenHABItemCacheTests.ITEMS_URL
        result = url?.absoluteString ?? ""
        XCTAssert(expected == result)

        Preferences.demomode = true

        url = instance.getURL()
        XCTAssert(instance.lastUrlConnected == OpenHABItemCache.URL_DEMO)
        expected = "https://demo.openhab.org" + OpenHABItemCacheTests.ITEMS_URL
        result = url?.absoluteString ?? ""
        XCTAssert(expected == result)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
