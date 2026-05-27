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
import Testing

// MARK: - Legacy partial-payload decoding (regression for home-name overwrite bug)

@MainActor
struct HomePreferencesDecodingTests {
    // Simulates stored data from an older version: only id + homeName + minimal connection
    // configs (missing supportsNotifications, username, password, and several HomePreferences
    // fields added later). Verifies that decode succeeds and the stored homeName is preserved.
    @Test func legacyPayloadPreservesHomeName() throws {
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "homeName": "My House",
            "localConnectionConfig": {
                "url": "https://local.example.com",
                "alwaysSendBasicAuth": false,
                "ignoreSSL": false,
                "priority": 0
            },
            "remoteConnectionConfig": {
                "url": "https://myopenhab.org",
                "alwaysSendBasicAuth": false,
                "ignoreSSL": false,
                "priority": 1
            }
        }
        """
        let prefs = try JSONDecoder().decode(HomePreferences.self, from: Data(json.utf8))

        #expect(prefs.homeName == "My House")
        #expect(prefs.localConnectionConfig.url == "https://local.example.com")
        #expect(prefs.remoteConnectionConfig.url == "https://myopenhab.org")
        // Missing HomePreferences fields must fall back to their struct defaults
        #expect(prefs.demomode == true)
        #expect(prefs.alwaysAllowWebRTC == false)
        #expect(prefs.sortSitemapsBy == 0)
        // Local config: missing supportsNotifications must default to false
        #expect(prefs.localConnectionConfig.supportsNotifications == false)
        // Remote config: missing supportsNotifications must default to true (role-aware)
        #expect(prefs.remoteConnectionConfig.supportsNotifications == true)
    }

    // Verifies that a payload with only the required `id` key decodes successfully and
    // all other fields fall back to their struct defaults, including homeName == "Home#1"
    // and remote supportsNotifications == true.
    @Test func minimalPayloadUsesDefaults() throws {
        let json = #"{"id":"550E8400-E29B-41D4-A716-446655440000"}"#
        let prefs = try JSONDecoder().decode(HomePreferences.self, from: Data(json.utf8))

        #expect(prefs.homeName == "Home#1")
        #expect(prefs.demomode == true)
        #expect(prefs.localConnectionConfig == .localDefault)
        #expect(prefs.remoteConnectionConfig == .remoteDefault)
    }

    // Verifies that an explicit supportsNotifications: false in the remote config JSON is
    // respected (not silently promoted to true by the role-aware default).
    @Test func explicitFalseNotificationsRespected() throws {
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "remoteConnectionConfig": {
                "url": "https://myopenhab.org",
                "supportsNotifications": false,
                "alwaysSendBasicAuth": false,
                "ignoreSSL": false,
                "priority": 1
            }
        }
        """
        let prefs = try JSONDecoder().decode(HomePreferences.self, from: Data(json.utf8))
        #expect(prefs.remoteConnectionConfig.supportsNotifications == false)
    }

    // Full round-trip: encode a HomePreferences, decode it, verify nothing is lost.
    @Test func fullRoundTripPreservesAllFields() throws {
        let encoded = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "homeName": "Custom Home",
            "demomode": false,
            "realTimeSliders": true,
            "iconType": 2,
            "defaultSitemap": "mymap",
            "sortSitemapsBy": 1,
            "defaultMainUIPath": "/overview",
            "alwaysAllowWebRTC": true,
            "sitemapForWatch": "watchmap",
            "sitemapForWatchLabel": "Watch Map",
            "sseCommandItem": "MySSEItem",
            "defaultView": "sitemap",
            "localConnectionConfig": {
                "url": "https://local.example.com",
                "username": "localuser",
                "password": "localpass",
                "alwaysSendBasicAuth": true,
                "ignoreSSL": true,
                "supportsNotifications": false,
                "priority": 0
            },
            "remoteConnectionConfig": {
                "url": "https://myopenhab.org",
                "username": "remoteuser",
                "password": "remotepass",
                "alwaysSendBasicAuth": false,
                "ignoreSSL": false,
                "supportsNotifications": true,
                "priority": 1
            }
        }
        """
        let prefs = try JSONDecoder().decode(HomePreferences.self, from: Data(encoded.utf8))
        let reencoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(HomePreferences.self, from: reencoded)

        #expect(decoded.homeName == "Custom Home")
        #expect(decoded.demomode == false)
        #expect(decoded.alwaysAllowWebRTC == true)
        // Credentials are not preserved in the re-encoded JSON (they move to Keychain);
        // the initial decode reads them as legacy fields, but encode strips them.
        #expect(decoded.localConnectionConfig.username.isEmpty)
        #expect(decoded.localConnectionConfig.supportsNotifications == false)
        #expect(decoded.remoteConnectionConfig.username.isEmpty)
        #expect(decoded.remoteConnectionConfig.supportsNotifications == true)
        #expect(decoded.sseCommandItem == "MySSEItem")
    }
}

// .serialized prevents parallel test clones from racing on the shared group.org.openhab.app UserDefaults suite.
@Suite(.serialized)
@MainActor
struct UserDefaultsTests {
    @Test func consistency() throws {
        let data = UserDefaults(suiteName: "group.org.openhab.app")!
        let defaultsName = try #require(Bundle.main.bundleIdentifier)
        data.removePersistentDomain(forName: defaultsName)

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

        // Non-credential properties round-trip through UserDefaults
        #expect(Preferences.shared.currentHomePreferences.localConnectionConfig.url == home.localConnectionConfig.url)
        #expect(Preferences.shared.currentHomePreferences.remoteConnectionConfig.url == home.remoteConnectionConfig.url)
        #expect(Preferences.shared.currentHomePreferences.remoteConnectionConfig.ignoreSSL == home.remoteConnectionConfig.ignoreSSL)
        #expect(Preferences.shared.currentHomePreferences.demomode == home.demomode)
        #expect(Preferences.shared.idleOff == data.bool(forKey: "idleOff"))
        #expect(Preferences.shared.currentHomePreferences.iconType == home.iconType)
        #expect(Preferences.shared.currentHomePreferences.defaultSitemap == home.defaultSitemap)
        #expect(Preferences.shared.currentHomePreferences.sitemapForWatch == home.sitemapForWatch)
        // Credentials are stored in Keychain, not in UserDefaults JSON
        var homeWithoutCredentials = home
        homeWithoutCredentials.localConnectionConfig.username = ""
        homeWithoutCredentials.localConnectionConfig.password = ""
        homeWithoutCredentials.remoteConnectionConfig.username = ""
        homeWithoutCredentials.remoteConnectionConfig.password = ""
        #expect(homeWithoutCredentials == (try? JSONDecoder().decode(HomePreferences.self, from: data.data(forKey: "currentHomePreferences")!)))
    }
}
