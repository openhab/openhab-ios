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

import Foundation
import OpenHABCore
import os.log
import SwiftUI

@Observable
final class AppSettings {
    @MainActor static let shared = AppSettings()

    /// Stable per-install identifier, analogous to UIDevice.identifierForVendor on iOS.
    static var deviceId: String {
        let key = "watchDeviceId"
        let store = UserDefaults.standard
        if let existing = store.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        store.set(new, forKey: key)
        return new
    }

    var openHABVersion = 2
    private let store: UserDefaults

    var localConnectionConfig: ConnectionConfiguration? {
        didSet {
            if let v = localConnectionConfig, let data = try? JSONEncoder().encode(v) {
                store.set(data, forKey: "localConnectionConfig")
            } else {
                store.removeObject(forKey: "localConnectionConfig")
            }
        }
    }

    var remoteConnectionConfig: ConnectionConfiguration? {
        didSet {
            if let v = remoteConnectionConfig, let data = try? JSONEncoder().encode(v) {
                store.set(data, forKey: "remoteConnectionConfig")
            } else {
                store.removeObject(forKey: "remoteConnectionConfig")
            }
        }
    }

    var openHABRootUrl: String {
        didSet { store.set(openHABRootUrl, forKey: "openHABRootUrl") }
    }

    var sitemapName: String {
        didSet { store.set(sitemapName, forKey: "sitemapName") }
    }

    var sitemapForWatch: String {
        didSet { store.set(sitemapForWatch, forKey: "sitemapForWatch") }
    }

    var sitemapForWatchLabel: String {
        didSet { store.set(sitemapForWatchLabel, forKey: "sitemapForWatchLabel") }
    }

    var iconType: IconType {
        didSet { store.set(iconType.rawValue, forKey: "iconType") }
    }

    var sitemapNameLabelDisplayMode: SitemapNameLabelDisplayMode {
        didSet { store.set(sitemapNameLabelDisplayMode.rawValue, forKey: "sitemapNameLabelDisplayMode") }
    }

    var sortSitemapsBy: SortSitemapsOrder {
        didSet { store.set(sortSitemapsBy.rawValue, forKey: "sortSitemapsBy") }
    }

    var haveReceivedAppContext = false

    var storedHomes: [UUID: HomePreferences] = [:] {
        didSet { Self.persistStoredHomes(storedHomes) }
    }

    /// UUID of the active home, persisted so credentials can be injected from Watch Keychain on restart.
    var activeHomeId: UUID? {
        didSet {
            if let activeHomeId {
                store.set(activeHomeId.uuidString, forKey: "activeHomeId")
            } else {
                store.removeObject(forKey: "activeHomeId")
            }
        }
    }

    init() {
        let store = UserDefaults(suiteName: "group.openhab.shared") ?? UserDefaults.standard
        self.store = store

        if let data = store.data(forKey: "localConnectionConfig"),
           let decoded = try? JSONDecoder().decode(ConnectionConfiguration.self, from: data) {
            localConnectionConfig = decoded
        } else {
            localConnectionConfig = nil
        }

        if let data = store.data(forKey: "remoteConnectionConfig"),
           let decoded = try? JSONDecoder().decode(ConnectionConfiguration.self, from: data) {
            remoteConnectionConfig = decoded
        } else {
            remoteConnectionConfig = nil
        }

        openHABRootUrl = store.string(forKey: "openHABRootUrl") ?? ""
        sitemapName = store.string(forKey: "sitemapName") ?? ""
        sitemapForWatch = store.string(forKey: "sitemapForWatch") ?? ""
        sitemapForWatchLabel = store.string(forKey: "sitemapForWatchLabel") ?? ""
        iconType = IconType(rawValue: store.integer(forKey: "iconType")) ?? .svg
        sitemapNameLabelDisplayMode = (store.object(forKey: "sitemapNameLabelDisplayMode") as? Int).flatMap(SitemapNameLabelDisplayMode.init(rawValue:)) ?? .label
        sortSitemapsBy = SortSitemapsOrder(rawValue: store.integer(forKey: "sortSitemapsBy")) ?? .label

        if let data = store.data(forKey: "watchAllHomes"),
           let decoded = try? JSONDecoder().decode([String: HomePreferences].self, from: data) {
            storedHomes = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                UUID(uuidString: key).map { ($0, value) }
            })
            // didSet doesn't fire during init, so seed the App Intents suite immediately.
            // The old @Published subscription emitted the initial value and called this automatically.
            Self.persistStoredHomes(storedHomes)
        }

        // Restore active home ID and inject credentials from Watch Keychain so the main
        // Watch UI has valid credentials even when the iOS app is not reachable on restart.
        if let uuidString = store.string(forKey: "activeHomeId"),
           let homeId = UUID(uuidString: uuidString) {
            activeHomeId = homeId
            if let creds = CredentialsStore.retrieve(homeId: homeId, type: .local) {
                localConnectionConfig?.username = creds.username
                localConnectionConfig?.password = creds.password
            }
            if let creds = CredentialsStore.retrieve(homeId: homeId, type: .remote) {
                remoteConnectionConfig?.username = creds.username
                remoteConnectionConfig?.password = creds.password
            }
        } else {
            activeHomeId = nil
        }
    }

    convenience init(debug: Bool = false, openHABRootUrl: String = "") {
        self.init()
        self.openHABRootUrl = openHABRootUrl
    }

    /// Writes `storedHomes` to both UserDefaults suites that read it:
    /// - `group.openhab.shared["watchAllHomes"]` (string-keyed) — read by `AppSettings.init()`
    /// - `group.org.openhab.app["storedHomes"]` (UUID-keyed) — read by `Preferences.shared` for App Intents
    static func persistStoredHomes(_ uuidKeyed: [UUID: HomePreferences]) {
        let stringKeyed = Dictionary(uniqueKeysWithValues: uuidKeyed.map { ($0.key.uuidString, $0.value) })
        let watchStore = UserDefaults(suiteName: "group.openhab.shared") ?? UserDefaults.standard
        if let data = try? JSONEncoder().encode(stringKeyed) {
            watchStore.set(data, forKey: "watchAllHomes")
        } else {
            Logger.preferences.error("Failed to persist storedHomes to group.openhab.shared")
        }
        let prefsStore = UserDefaults(suiteName: "group.org.openhab.app") ?? UserDefaults.standard
        if let data = try? JSONEncoder().encode(uuidKeyed) {
            prefsStore.set(data, forKey: "storedHomes")
        } else {
            Logger.preferences.error("Failed to persist storedHomes to group.org.openhab.app")
        }
    }
}
