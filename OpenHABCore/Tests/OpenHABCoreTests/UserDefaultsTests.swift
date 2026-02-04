// Copyright (c) 2010-2026 Contributors to the openHAB project
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
        data.removePersistentDomain(forName: "group.org.openhab.app")
        Preferences.reloadForTesting()

        let random: String = UUID().uuidString

        var home = Preferences.shared.currentHomePreferences
        home.remoteConnectionConfig.username = "testuser\(random)"
        home.localConnectionConfig.url = "http://local\(random).test"
        home.remoteConnectionConfig.url = "http://remote\(random).test"
        home.remoteConnectionConfig.password = "secret\(random)"
        home.remoteConnectionConfig.ignoreSSL = true
        home.demomode = true
        home.iconType = 2
        home.defaultSitemap = "default\(random)"
        home.sitemapForWatch = "watchmap\(random)"

        Preferences.shared.modifyActiveHome { preferences in
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

        Preferences.shared.idleOff = false

        XCTAssertEqual(Preferences.shared.currentHomePreferences.remoteConnectionConfig.username, home.remoteConnectionConfig.username)
        XCTAssertEqual(Preferences.shared.currentHomePreferences.localConnectionConfig.url, home.localConnectionConfig.url)
        XCTAssertEqual(Preferences.shared.currentHomePreferences.remoteConnectionConfig.url, home.remoteConnectionConfig.url)
        XCTAssertEqual(Preferences.shared.currentHomePreferences.remoteConnectionConfig.password, home.remoteConnectionConfig.password)
        XCTAssertEqual(Preferences.shared.currentHomePreferences.remoteConnectionConfig.ignoreSSL, home.remoteConnectionConfig.ignoreSSL)
        XCTAssertEqual(Preferences.shared.currentHomePreferences.demomode, home.demomode)
        XCTAssertEqual(Preferences.shared.idleOff, data.bool(forKey: "idleOff"))
        XCTAssertEqual(Preferences.shared.currentHomePreferences.iconType, home.iconType)
        XCTAssertEqual(Preferences.shared.currentHomePreferences.defaultSitemap, home.defaultSitemap)
        XCTAssertEqual(Preferences.shared.currentHomePreferences.sitemapForWatch, home.sitemapForWatch)

        let storeData = try XCTUnwrap(data.data(forKey: "preferencesStore"))
        let storeObject = try XCTUnwrap(JSONSerialization.jsonObject(with: storeData) as? [String: Any])
        XCTAssertEqual(storeObject["version"] as? Int, 1)
        XCTAssertNotNil(storeObject["currentHomePreferences"])
    }

    func testPreferencesStoreForwardCompatibility() throws {
        let data = UserDefaults(suiteName: "group.org.openhab.app")!
        data.removePersistentDomain(forName: "group.org.openhab.app")

        Preferences.reloadForTesting()
        let home = Preferences.shared.currentHomePreferences
        let homeId = home.id
        let homeData = try JSONEncoder().encode(home)
        let homeObject = try XCTUnwrap(JSONSerialization.jsonObject(with: homeData) as? [String: Any])

        let appPrefs = ApplicationPreferences()
        let appPrefsData = try JSONEncoder().encode(appPrefs)
        let appPrefsObject = try XCTUnwrap(JSONSerialization.jsonObject(with: appPrefsData) as? [String: Any])

        let storedHomesObject: [String: Any] = [homeId.uuidString: homeObject]

        var legacyStore: [String: Any] = [
            "version": 1,
            "currentHomePreferences": homeObject,
            "storedHomes": storedHomesObject,
            "activeHomeId": homeId.uuidString,
            "applicationPreferences": appPrefsObject,
            "sendCrashReports": true,
            "idleOff": true,
            "screensaverEnabled": false,
            "screensaverShowsTime": true,
            "screensaverShowsDate": true,
            "screensaverIdleInterval": 120.0,
            "screensaverMovementInterval": 8.0,
            "screensaverFontName": "",
            "screensaverTimeFontRatio": 0.2,
            "screensaverDateFontRatio": 0.4,
            "screensaverEnableDimming": true,
            "screensaverDimLevel": 0.3,
            "screensaverShowsSeconds": false,
            "screensaverUse24Hour": false,
            "screensaverFadeDuration": 2.0,
            "screensaverRestoreBrightness": true,
            "screensaverWakeBrightness": 1.0,
            "hideStatusBar": false
        ]

        // Deliberately omit currentWebViewPath to simulate older payloads
        let legacyData = try JSONSerialization.data(withJSONObject: legacyStore)
        data.set(legacyData, forKey: "preferencesStore")

        Preferences.reloadForTesting()

        XCTAssertTrue(Preferences.shared.sendCrashReports)
        XCTAssertTrue(Preferences.shared.idleOff)
        XCTAssertEqual(Preferences.shared.currentWebViewPath, "")
    }
}
