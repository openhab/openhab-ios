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

        #expect(Preferences.shared.currentHomePreferences.remoteConnectionConfig.username == home.remoteConnectionConfig.username)
        #expect(Preferences.shared.currentHomePreferences.localConnectionConfig.url == home.localConnectionConfig.url)
        #expect(Preferences.shared.currentHomePreferences.remoteConnectionConfig.url == home.remoteConnectionConfig.url)
        #expect(Preferences.shared.currentHomePreferences.remoteConnectionConfig.password == home.remoteConnectionConfig.password)
        #expect(Preferences.shared.currentHomePreferences.remoteConnectionConfig.ignoreSSL == home.remoteConnectionConfig.ignoreSSL)
        #expect(Preferences.shared.currentHomePreferences.demomode == home.demomode)
        #expect(Preferences.shared.idleOff == data.bool(forKey: "idleOff"))
        #expect(Preferences.shared.currentHomePreferences.iconType == home.iconType)
        #expect(Preferences.shared.currentHomePreferences.defaultSitemap == home.defaultSitemap)
        #expect(Preferences.shared.currentHomePreferences.sitemapForWatch == home.sitemapForWatch)
        #expect(home == (try? JSONDecoder().decode(HomePreferences.self, from: data.data(forKey: "currentHomePreferences")!)))
    }
}
