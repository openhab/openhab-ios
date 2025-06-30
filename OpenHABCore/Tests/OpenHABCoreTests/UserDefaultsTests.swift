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

        let random: String = UUID().uuidString

        var home = Preferences.currentHomePreferences
        home.remoteConnectionConfig.username = "testuser\(random)"
        home.localConnectionConfig.url = "http://local\(random).test"
        home.remoteConnectionConfig.url = "http://remote\(random).test"
        home.remoteConnectionConfig.password = "secret\(random)"
        home.remoteConnectionConfig.ignoreSSL = true
        home.demomode = true
        home.iconType = 2
        home.defaultSitemap = "default\(random)"
        home.sitemapForWatch = "watchmap\(random)"

        Preferences.modifyActiveHome { preferences in
            preferences.remoteConnectionConfig.username = "testuser\(random)"
            preferences.localConnectionConfig.url = "http://local\(random).test"
            preferences.remoteConnectionConfig.url = "http://remote\(random).test"
            preferences.remoteConnectionConfig.password = "secret\(random)"
            preferences.remoteConnectionConfig.ignoreSSL = true
            preferences.demomode = true
            preferences.iconType = 2
            preferences.defaultSitemap = "default\(random)"
            preferences.sitemapForWatch = "watchmap\(random)"
        }

        Preferences.idleOff = false

        XCTAssertEqual(Preferences.currentHomePreferences.remoteConnectionConfig.username, home.remoteConnectionConfig.username)
        XCTAssertEqual(Preferences.currentHomePreferences.localConnectionConfig.url, home.localConnectionConfig.url)
        XCTAssertEqual(Preferences.currentHomePreferences.remoteConnectionConfig.url, home.remoteConnectionConfig.url)
        XCTAssertEqual(Preferences.currentHomePreferences.remoteConnectionConfig.password, home.remoteConnectionConfig.password)
        XCTAssertEqual(Preferences.currentHomePreferences.remoteConnectionConfig.ignoreSSL, home.remoteConnectionConfig.ignoreSSL)
        XCTAssertEqual(Preferences.currentHomePreferences.demomode, home.demomode)
        XCTAssertEqual(Preferences.idleOff, data.bool(forKey: "idleOff"))
        XCTAssertEqual(Preferences.currentHomePreferences.iconType, home.iconType)
        XCTAssertEqual(Preferences.currentHomePreferences.defaultSitemap, home.defaultSitemap)
        XCTAssertEqual(Preferences.currentHomePreferences.sitemapForWatch, home.sitemapForWatch)
        XCTAssertEqual(home, try? JSONDecoder().decode(HomePreferences.self, from: data.data(forKey: "currentHomePreferences")!))
    }
}
