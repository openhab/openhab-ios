//
//  OpenHABUserDefaultsTests.swift
//  openHABTestsSwift
//
//  Created by Tim Müller-Seydlitz on 29.08.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import XCTest

class OpenHABUserDefaultsTests: XCTestCase {

    // Testing the consistency between properties of Preferences and the corresponding entry in UserDefaults
    func testConsistency() {

        XCTAssertEqual(Preferences.username, UserDefaults.standard.string(forKey: "username"))
        XCTAssertNotEqual(Preferences.username, UserDefaults.standard.string(forKey: "usern"))

        XCTAssertEqual(Preferences.localUrl, UserDefaults.standard.string(forKey: "localUrl"))
        XCTAssertEqual(Preferences.remoteUrl, UserDefaults.standard.string(forKey: "remoteUrl"))
        XCTAssertEqual(Preferences.username, UserDefaults.standard.string(forKey: "username"))
        XCTAssertEqual(Preferences.password, UserDefaults.standard.string(forKey: "password"))
        XCTAssertEqual(Preferences.ignoreSSL, UserDefaults.standard.bool(forKey: "ignoreSSL"))
      //  XCTAssertEqual(Preferences.sitemapName, UserDefaults.standard.string(forKey: "sitemapName"))
        XCTAssertEqual(Preferences.demomode, UserDefaults.standard.bool(forKey: "demomode"))
        XCTAssertEqual(Preferences.idleOff, UserDefaults.standard.bool(forKey: "idleOff"))
        XCTAssertEqual(Preferences.iconType, UserDefaults.standard.integer(forKey: "iconType"))
        XCTAssertEqual(Preferences.defaultSitemap, UserDefaults.standard.string(forKey: "defaultSitemap"))
    }
}
