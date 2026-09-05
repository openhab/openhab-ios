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
    /// Simulates stored data from an older version: only id + homeName + minimal connection
    /// configs (missing supportsNotifications, username, password, and several HomePreferences
    /// fields added later). Verifies that decode succeeds and the stored homeName is preserved.
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

    /// Verifies that a payload with only the required `id` key decodes successfully and
    /// all other fields fall back to their struct defaults, including homeName == "Home#1"
    /// and remote supportsNotifications == true.
    @Test func minimalPayloadUsesDefaults() throws {
        let json = #"{"id":"550E8400-E29B-41D4-A716-446655440000"}"#
        let prefs = try JSONDecoder().decode(HomePreferences.self, from: Data(json.utf8))

        #expect(prefs.homeName == "Home#1")
        #expect(prefs.demomode == true)
        #expect(prefs.localConnectionConfig == .localDefault)
        #expect(prefs.remoteConnectionConfig == .remoteDefault)
    }

    /// Verifies that an explicit supportsNotifications: false in the remote config JSON is
    /// respected (not silently promoted to true by the role-aware default).
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

    /// Full round-trip: encode a HomePreferences, decode it, verify nothing is lost.
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

// Actor-isolated shims used only by UserDefaultsTests.
// Two limitations apply when calling Preferences from outside the actor:
//   1. var property setters cannot be called with await — a method is required.
//   2. (inout HomePreferences) -> Void is not @Sendable, so it cannot cross the
//      actor boundary. A value-returning (HomePreferences) -> HomePreferences
//      closure is used instead and bridged to modifyActiveHome internally.
private extension Preferences {
    func setIdleOff(_ value: Bool) { idleOff = value }

    func modifyActiveHomeForTests(_ block: @Sendable (HomePreferences) -> HomePreferences) {
        modifyActiveHome { prefs in prefs = block(prefs) }
    }
}

/// .serialized prevents parallel test clones from racing on the shared group.org.openhab.app UserDefaults suite.
@Suite(.serialized)
@MainActor
struct UserDefaultsTests {
    @Test func consistency() async throws {
        let data = try #require(UserDefaults(suiteName: "group.org.openhab.app"))
        let defaultsName = try #require(Bundle.main.bundleIdentifier)
        data.removePersistentDomain(forName: defaultsName)

        let random: String = UUID().uuidString

        var home = await Preferences.shared.currentHomePreferences
        home.remoteConnectionConfig.username = "testuser\(random)"
        home.localConnectionConfig.url = "http://local\(random).test"
        home.remoteConnectionConfig.url = "http://remote\(random).test"
        home.remoteConnectionConfig.password = "secret\(random)"
        home.remoteConnectionConfig.ignoreSSL = true
        home.demomode = true
        home.iconType = 2
        home.defaultSitemap = "default\(random)"
        home.sitemapForWatch = "watchmap\(random)"

        await Preferences.shared.modifyActiveHomeForTests { prefs in
            var p = prefs
            p.remoteConnectionConfig.username = "testuser\(random)"
            p.localConnectionConfig.url = "http://local\(random).test"
            p.remoteConnectionConfig.url = "http://remote\(random).test"
            p.remoteConnectionConfig.password = "secret\(random)"
            p.remoteConnectionConfig.ignoreSSL = true
            p.demomode = true
            p.iconType = 2
            p.defaultSitemap = "default\(random)"
            p.sitemapForWatch = "watchmap\(random)"
            return p
        }

        await Preferences.shared.setIdleOff(false)

        // Pre-fetch actor-isolated values; #expect expands into sync closures so
        // await cannot appear directly inside the macro invocations.
        let storedPrefs = await Preferences.shared.currentHomePreferences
        let storedIdleOff = await Preferences.shared.idleOff

        // Non-credential properties round-trip through UserDefaults
        #expect(storedPrefs.localConnectionConfig.url == home.localConnectionConfig.url)
        #expect(storedPrefs.remoteConnectionConfig.url == home.remoteConnectionConfig.url)
        #expect(storedPrefs.remoteConnectionConfig.ignoreSSL == home.remoteConnectionConfig.ignoreSSL)
        #expect(storedPrefs.demomode == home.demomode)
        #expect(storedIdleOff == data.bool(forKey: "idleOff"))
        #expect(storedPrefs.iconType == home.iconType)
        #expect(storedPrefs.defaultSitemap == home.defaultSitemap)
        #expect(storedPrefs.sitemapForWatch == home.sitemapForWatch)
        // Credentials are stored in Keychain, not in UserDefaults JSON
        var homeWithoutCredentials = home
        homeWithoutCredentials.localConnectionConfig.username = ""
        homeWithoutCredentials.localConnectionConfig.password = ""
        homeWithoutCredentials.remoteConnectionConfig.username = ""
        homeWithoutCredentials.remoteConnectionConfig.password = ""
        #expect(homeWithoutCredentials == (try? JSONDecoder().decode(HomePreferences.self, from: try #require(data.data(forKey: "currentHomePreferences")))))
    }
}

// MARK: - MenuSection + HomePreferences menu-improvement fields

@Suite("MenuSection and HomePreferences menu fields")
@MainActor
struct MenuSectionTests {
    /// Old payload missing the new fields must decode successfully and resolve defaults.
    @Test func newFieldsDefaultOnOldPayload() throws {
        let json = #"{"id":"550E8400-E29B-41D4-A716-446655440000"}"#
        let prefs = try JSONDecoder().decode(HomePreferences.self, from: Data(json.utf8))

        #expect(prefs.avatarImagePath == nil)
        #expect(prefs.sectionOrder == MenuSection.allCases)
        #expect(prefs.isMainUIVisible == nil)
        #expect(prefs.isSitemapsVisible == nil)
        #expect(prefs.isTilesVisible == nil)
        #expect(prefs.isSystemVisible == nil)
    }

    /// A custom section order round-trips through encode → decode unchanged.
    @Test func sectionOrderRoundTrip() throws {
        let json = #"{"id":"550E8400-E29B-41D4-A716-446655440000"}"#
        var prefs = try JSONDecoder().decode(HomePreferences.self, from: Data(json.utf8))

        let customOrder: [MenuSection] = [.tiles, .sitemaps, .mainUI, .system]
        prefs.sectionOrder = customOrder

        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(HomePreferences.self, from: encoded)
        #expect(decoded.sectionOrder == customOrder)
    }

    /// Visibility flags round-trip correctly.
    @Test func visibilityFlagsRoundTrip() throws {
        let json = #"{"id":"550E8400-E29B-41D4-A716-446655440000"}"#
        var prefs = try JSONDecoder().decode(HomePreferences.self, from: Data(json.utf8))

        prefs.isMainUIVisible = false
        prefs.isTilesVisible = true

        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(HomePreferences.self, from: encoded)
        #expect(decoded.isMainUIVisible == false)
        #expect(decoded.isTilesVisible == true)
        #expect(decoded.isSitemapsVisible == nil) // unset fields stay nil
        #expect(decoded.isSystemVisible == nil)
    }

    /// avatarImagePath round-trips correctly.
    @Test func avatarImagePathRoundTrip() throws {
        let json = #"{"id":"550E8400-E29B-41D4-A716-446655440000"}"#
        var prefs = try JSONDecoder().decode(HomePreferences.self, from: Data(json.utf8))

        prefs.avatarImagePath = "/Library/Application Support/homes/test.jpg"

        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(HomePreferences.self, from: encoded)
        #expect(decoded.avatarImagePath == "/Library/Application Support/homes/test.jpg")
    }
}
