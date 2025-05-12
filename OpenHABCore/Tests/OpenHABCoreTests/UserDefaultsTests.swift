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

import XCTest

@MainActor
final class UserDefaultsTests: XCTestCase {
    // Testing the consistency between Preferences and UserDefaults
    func testConsistency() {
        // Set Preferences from MainActor
        let defaultsName: String
        // Reset UserDefaults
        let data = UserDefaults(suiteName: "group.org.openhab.app")!
        do {
            defaultsName = try XCTUnwrap(Bundle.main.bundleIdentifier)
        } catch {
            fatalError()
        }
        data.removePersistentDomain(forName: defaultsName)

        Preferences.username = "testuser"
        Preferences.localUrl = "http://local.test"
        Preferences.remoteUrl = "http://remote.test"
        Preferences.password = "secret"
        Preferences.ignoreSSL = true
        Preferences.demomode = true
        Preferences.idleOff = false
        Preferences.iconType = 2
        Preferences.defaultSitemap = "default"
        Preferences.sitemapForWatch = "watchmap"

        XCTAssertEqual(Preferences.username, data.string(forKey: "username"))
        XCTAssertEqual(Preferences.localUrl, data.string(forKey: "localUrl"))
        XCTAssertEqual(Preferences.remoteUrl, data.string(forKey: "remoteUrl"))
        XCTAssertEqual(Preferences.password, data.string(forKey: "password"))
        XCTAssertEqual(Preferences.ignoreSSL, data.bool(forKey: "ignoreSSL"))
        XCTAssertEqual(Preferences.demomode, data.bool(forKey: "demomode"))
        XCTAssertEqual(Preferences.idleOff, data.bool(forKey: "idleOff"))
        XCTAssertEqual(Preferences.iconType, data.integer(forKey: "iconType"))
        XCTAssertEqual(Preferences.defaultSitemap, data.string(forKey: "defaultSitemap"))
        XCTAssertEqual(Preferences.sitemapForWatch, data.string(forKey: "sitemapForWatch"))
    }
}
