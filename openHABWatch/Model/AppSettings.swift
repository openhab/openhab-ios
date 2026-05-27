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

import Combine
import Foundation
import OpenHABCore
import os.log
import SwiftUI

final class AppSettings: ObservableObject {
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
    var cancellables = Set<AnyCancellable>()

    @Published var localConnectionConfig: ConnectionConfiguration?
    @Published var remoteConnectionConfig: ConnectionConfiguration?
    @Published var openHABRootUrl: String
    @Published var sitemapName: String
    @Published var sitemapForWatch: String
    @Published var sitemapForWatchLabel: String
    @Published var iconType: IconType
    @Published var haveReceivedAppContext = false
    @Published var storedHomes: [UUID: HomePreferences] = [:]

    init() {
        let store = UserDefaults(suiteName: "group.openhab.shared") ?? UserDefaults.standard

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

        if let data = store.data(forKey: "watchAllHomes"),
           let decoded = try? JSONDecoder().decode([String: HomePreferences].self, from: data) {
            storedHomes = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                UUID(uuidString: key).map { ($0, value) }
            })
        }

        // Observe changes and write back to UserDefaults
        $localConnectionConfig
            .sink { newValue in
                if let newValue,
                   let data = try? JSONEncoder().encode(newValue) {
                    store.set(data, forKey: "localConnectionConfig")
                } else {
                    store.removeObject(forKey: "localConnectionConfig")
                }
            }
            .store(in: &cancellables)

        $remoteConnectionConfig
            .sink { newValue in
                if let newValue,
                   let data = try? JSONEncoder().encode(newValue) {
                    store.set(data, forKey: "remoteConnectionConfig")
                } else {
                    store.removeObject(forKey: "remoteConnectionConfig")
                }
            }
            .store(in: &cancellables)

        $openHABRootUrl
            .removeDuplicates()
            .sink { newValue in
                store.set(newValue, forKey: "openHABRootUrl")
            }
            .store(in: &cancellables)

        $sitemapName
            .removeDuplicates()
            .sink { newValue in
                store.set(newValue, forKey: "sitemapName")
            }
            .store(in: &cancellables)

        $sitemapForWatch
            .removeDuplicates()
            .sink { newValue in
                store.set(newValue, forKey: "sitemapForWatch")
            }
            .store(in: &cancellables)

        $sitemapForWatchLabel
            .removeDuplicates()
            .sink { newValue in
                store.set(newValue, forKey: "sitemapForWatchLabel")
            }
            .store(in: &cancellables)

        $iconType
            .removeDuplicates()
            .sink { newValue in
                store.set(newValue.rawValue, forKey: "iconType")
            }
            .store(in: &cancellables)

        $storedHomes
            .removeDuplicates()
            .sink { newValue in
                Self.persistStoredHomes(newValue)
            }
            .store(in: &cancellables)
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
