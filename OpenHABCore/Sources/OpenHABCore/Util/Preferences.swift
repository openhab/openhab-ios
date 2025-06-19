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

@preconcurrency import Combine
import os.log
import UIKit

@propertyWrapper @MainActor
public struct UserDefault<T: Sendable> {
    private let key: String
    private let defaultValue: T
    private let store: Bool
    private let subject: CurrentValueSubject<T, Never>

    public var wrappedValue: T {
        get {
            Preferences.getPreference(key: key, defaultValue: defaultValue, encoder: { $0 }, decoder: { $0 as? T })
        }
        set {
            Preferences.preferenceChanged(newValue: newValue, key: key, store: store, subject: subject) { $0 }
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(_ key: String, defaultValue: T, store: Bool = true) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
        let currentValue = Preferences.getPreference(key: key, defaultValue: defaultValue, encoder: { $0 }, decoder: { $0 as? T })
        subject = CurrentValueSubject<T, Never>(currentValue)
    }
}

@propertyWrapper @MainActor
public struct UserDefaultObject<T: Codable & Sendable> {
    private let key: String
    private let defaultValue: T
    private let store: Bool
    private let subject: CurrentValueSubject<T, Never>

    private let objectDecoder: (Any) -> (T?) = {
        guard let data = $0 as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private let objectEncoder: (T) -> (any Sendable)? = { try? JSONEncoder().encode($0) }

    public var wrappedValue: T {
        get {
            Preferences.getPreference(key: key, defaultValue: defaultValue, encoder: objectEncoder, decoder: objectDecoder)
        }
        set {
            Preferences.preferenceChanged(newValue: newValue, key: key, store: store, subject: subject, converter: objectEncoder)
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    init(_ key: String, defaultValue: T, store: Bool = true) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store

        // Combine publication
        let currentValue = Preferences.getPreference(key: key, defaultValue: defaultValue, encoder: objectEncoder, decoder: objectDecoder)
        subject = CurrentValueSubject(currentValue)
    }
}

@propertyWrapper @MainActor
public struct UserDefaultURL {
    private static let urlSanitizer: (String) -> (String?) = {
        // Trim and validate the new URL
        let trimmedUri = $0.removeTrailingSlashes().trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedUri.isValidURL || trimmedUri.isEmpty else { // empty is the default for localUrl
            return nil
        }
        return trimmedUri
    }

    private static let urlConverter: (Any) -> (String?) = {
        guard let preferenceString = $0 as? String else {
            return nil
        }
        return urlSanitizer(preferenceString)
    }

    private let key: String
    private let defaultValue: String
    private let store: Bool
    private let subject: CurrentValueSubject<String, Never>

    public var wrappedValue: String {
        get {
            Preferences.getPreference(key: key, defaultValue: defaultValue, encoder: UserDefaultURL.urlSanitizer, decoder: UserDefaultURL.urlConverter)
        }
        set {
            Preferences.preferenceChanged(newValue: newValue, key: key, store: true, subject: subject, sanitize: UserDefaultURL.urlSanitizer) { $0 }
        }
    }

    public var projectedValue: AnyPublisher<String, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(_ key: String, defaultValue: String, store: Bool = true) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
        let currentValue = Preferences.getPreference(key: key, defaultValue: defaultValue, encoder: { $0 }, decoder: UserDefaultURL.urlConverter)
        subject = CurrentValueSubject<String, Never>(currentValue)
    }
}

// TODO: We should refactor this class to use an instance of this struct rather then setting preferences values directly on ourself
// so instead of Preferences.demomode it could be Preferences.active.demomode or something. Requires a heafty refactor.
public struct PreferenceInstance: Sendable {
    public let id: UUID
    public let defaultView: String
    public let demomode: Bool
    public let realTimeSliders: Bool
    public let iconType: Int
    public let defaultSitemap: String
    public let sortSitemapsBy: Int
    public let defaultMainUIPath: String
    public let alwaysAllowWebRTC: Bool
    public let sitemapForWatch: String
    public let localConnectionConfig: ConnectionConfiguration
    public let remoteConnectionConfig: ConnectionConfiguration
    public let sitemapForWatchLabel: String
    public let homeName: String

    fileprivate init?(id: UUID, dict: [String: any Sendable]) {
        guard
            let localData = dict["localConnectionConfig"] as? Data,
            let remoteData = dict["remoteConnectionConfig"] as? Data,
            let localCfg = try? JSONDecoder().decode(ConnectionConfiguration.self, from: localData),
            let remoteCfg = try? JSONDecoder().decode(ConnectionConfiguration.self, from: remoteData)
        else { return nil }

        self.id = id
        defaultView = dict["defaultView"] as? String ?? "web"
        demomode = dict["demomode"] as? Bool ?? true
        realTimeSliders = dict["realTimeSliders"] as? Bool ?? false
        iconType = dict["iconType"] as? Int ?? 0
        defaultSitemap = dict["defaultSitemap"] as? String ?? "demo"
        sortSitemapsBy = dict["sortSitemapsBy"] as? Int ?? 0
        defaultMainUIPath = dict["defaultMainUIPath"] as? String ?? ""
        alwaysAllowWebRTC = dict["alwaysAllowWebRTC"] as? Bool ?? false
        sitemapForWatch = dict["sitemapForWatch"] as? String ?? "watch"
        localConnectionConfig = localCfg
        remoteConnectionConfig = remoteCfg
        sitemapForWatchLabel = dict["sitemapForWatchLabel"] as? String ?? "watch"
        homeName = dict["homeName"] as? String ?? "Home"
    }
}

@MainActor
public enum Preferences {
    static let sharedDefaults = UserDefaults(suiteName: "group.org.openhab.app")!

    // MARK: - Public Deprecated preferences

    @UserDefaultURL("localUrl", defaultValue: "", store: false) public static var localUrl: String
    @UserDefaultURL("remoteUrl", defaultValue: "https://myopenhab.org", store: false) public static var remoteUrl: String
    @UserDefault("username", defaultValue: "test", store: false) public static var username: String
    @UserDefault("password", defaultValue: "test", store: false) public static var password: String
    @UserDefault("alwaysSendCreds", defaultValue: false, store: false) public static var alwaysSendCreds: Bool
    @UserDefault("ignoreSSL", defaultValue: false, store: false) public static var ignoreSSL: Bool

    // MARK: - Public Home related preferences

    @UserDefaultURL("defaultView", defaultValue: "web") public static var defaultView: String
    @UserDefault("demomode", defaultValue: true) public static var demomode: Bool
    @UserDefault("realTimeSliders", defaultValue: false) public static var realTimeSliders: Bool
    @UserDefault("iconType", defaultValue: 0) public static var iconType: Int
    @UserDefault("defaultSitemap", defaultValue: "demo") public static var defaultSitemap: String
    @UserDefault("sortSitemapsBy", defaultValue: 0) public static var sortSitemapsBy: Int
    @UserDefault("defaultMainUIPath", defaultValue: "") public static var defaultMainUIPath: String
    @UserDefault("alwaysAllowWebRTC", defaultValue: false) public static var alwaysAllowWebRTC: Bool
    @UserDefault("sitemapForWatch", defaultValue: "watch") public static var sitemapForWatch: String
    @UserDefaultObject("localConnectionConfig", defaultValue: ConnectionConfiguration.localDefault) public static var localConnectionConfig: ConnectionConfiguration
    @UserDefaultObject("remoteConnectionConfig", defaultValue: ConnectionConfiguration.remoteDefault) public static var remoteConnectionConfig: ConnectionConfiguration
    @UserDefault("sitemapForWatchLabel", defaultValue: "watch") public static var sitemapForWatchLabel: String
    @UserDefault("homeName", defaultValue: "Home") public static var homeName: String

    // MARK: - Public App related preferences

    @UserDefault("sendCrashReports", defaultValue: false, store: false) public static var sendCrashReports: Bool

    @UserDefault("idleOff", defaultValue: false, store: false) public static var idleOff: Bool

    /// settings for different homes TODO come up with better name
    @UserDefault("storedPreferences", defaultValue: [:], store: false) public static var storedPreferences: [String: [String: any Sendable]]

    // MARK: - Private preferences

    /// the currently applied settings set from storedPreferences
    @UserDefault("currentlyUsedSettings", defaultValue: UUID().uuidString, store: false) public private(set) static var currentlyUsedSettings: String

    @UserDefault("didMigrateToSharedDefaults", defaultValue: false, store: false) private static var didMigrateToSharedDefaults: Bool
    @UserDefault("didMigrateToConnectionConfig", defaultValue: false, store: false) private static var didMigrateToConnectionConfig: Bool
    @UserDefault("currentWebViewPath", defaultValue: "", store: false) public static var currentWebViewPath: String

    private static var loadingStoredPreferences = false
}

// MARK: Retrieving preference from user defaults, reacting to preference change

private extension Preferences {
    static func getPreference<T>(key: String, defaultValue: T, encoder: (T) -> (some Sendable)?, decoder: (Any?) -> T?) -> T {
        let preferenceValue = Preferences.sharedDefaults.object(forKey: key)
        if let preferenceConverted = decoder(preferenceValue) {
            os_log(
                "Preference value %{PUBLIC}@ is %{PUBLIC}@",
                log: .default,
                type: .debug,
                key,
                "\(preferenceConverted)"
            )
            return preferenceConverted
        } else {
            if let preferenceValue {
                os_log(
                    "Preference value %{PUBLIC}@ was \"%{PUBLIC}@\" but did not conform to %{PUBLIC}@. Replace with default value.",
                    log: .default,
                    type: .fault,
                    key,
                    "\(preferenceValue)",
                    "\(T.self)"
                )
            } else {
                os_log(
                    "Preference value %{PUBLIC}@ was set for the first time. Using default value.",
                    log: .default,
                    type: .info,
                    key
                )
            }
            let fallback = defaultValue
            Preferences.sharedDefaults.set(encoder(fallback), forKey: key)
            return fallback
        }
    }

    static func preferenceChanged<T>(newValue: T, key: String, store: Bool, subject: CurrentValueSubject<T, Never>, sanitize: (T) -> (T?) = { $0 }, converter: (T) -> (some Sendable)?) {
        guard let sanitized = sanitize(newValue) else {
            os_log("Preference %{PUBLIC}@ new value \"%{PUBLIC}@\" could not be sanitized, will be ignored", log: .default, type: .debug, key, "\(newValue)")
            return
        }
        let convertedValue = converter(sanitized)
        guard convertedValue != nil else {
            os_log("Preference %{PUBLIC}@ conversion of new value %{PUBLIC}@ failed, do not store.", log: .default, type: .debug, key, "\(sanitized)")
            return
        }
        os_log("Preference %{PUBLIC}@ will be changed to value %{PUBLIC}@", log: .default, type: .debug, key, "\(newValue)")
        Preferences.sharedDefaults.set(convertedValue, forKey: key)
        if store {
            Preferences.storeCurrentPreferences(updatedKey: key, updatedValue: convertedValue)
        }
        DispatchQueue.main.async { [subject] in
            subject.send(sanitized)
        }
    }
}

// MARK: Multiple homes

@MainActor
public extension Preferences {
    static func listStoredPreferences() -> [UUID] {
        let preferenceIds = storedPreferences
            .sorted { e1, e2 in
                (e1.value["homeName"] as? String ?? "") <= (e2.value["homeName"] as? String ?? "")
            }
            .map(\.key)
        return preferenceIds.compactMap { UUID(uuidString: $0) }
    }

    static func getCurrentlyUsedSettings() -> UUID {
        guard let currentPreferenceUUID = UUID(uuidString: currentlyUsedSettings) else {
            fatalError("currentlyUsedSettings must be a UUID, but was \(currentlyUsedSettings)")
        }
        return currentPreferenceUUID
    }

    static func initializeStoredPreferences() {
        if storedPreferences.isEmpty {
            // first there might be no stored preferences, if no preference was changed since the update
            storeCurrentPreferences()
        }
    }

    static func createAndLoadNewStoredSettings(homeName: String) {
        currentlyUsedSettings = UUID().uuidString
        loadSettings(stored: ["homeName": homeName])
    }

    static func renameHome(_ settingsId: UUID, newHomeName: String) {
        var stored = storedPreferences
        stored[settingsId.uuidString]?["homeName"] = newHomeName
        storedPreferences = stored
    }

    static func deleteStoredSettings(_ settingsId: UUID) {
        guard settingsId != getCurrentlyUsedSettings() else {
            // cannot remove current home
            return
        }
        var stored = storedPreferences
        stored.removeValue(forKey: settingsId.uuidString)
        storedPreferences = stored
    }

    static func switchCurrentlyUsedSettings(to settingsId: UUID) {
        let settingsIdString = settingsId.uuidString

        guard let stored = storedPreferences[settingsIdString] else {
            // we have not stored our settings in that list yet
            return
        }

        Preferences.currentlyUsedSettings = settingsIdString

        loadSettings(stored: stored)
    }

    private static func loadSettings(stored: [String: Any]) {
        loadingStoredPreferences = true
        // TODO: not pretty to repeat everything here
        Preferences.defaultView = stored["defaultView"] as? String ?? "web"
        Preferences.demomode = stored["demomode"] as? Bool ?? true
        Preferences.realTimeSliders = stored["realTimeSliders"] as? Bool ?? false
        Preferences.iconType = stored["iconType"] as? Int ?? 0
        Preferences.defaultSitemap = stored["defaultSitemap"] as? String ?? "demo"
        Preferences.sortSitemapsBy = stored["sortSitemapsBy"] as? Int ?? 0
        Preferences.defaultMainUIPath = stored["defaultMainUIPath"] as? String ?? ""
        Preferences.alwaysAllowWebRTC = stored["alwaysAllowWebRTC"] as? Bool ?? false
        Preferences.sitemapForWatch = stored["sitemapForWatch"] as? String ?? "watch"
        Preferences.localConnectionConfig = (try? JSONDecoder().decode(ConnectionConfiguration.self, from: stored["localConnectionConfig"] as? Data ?? Data())) ?? ConnectionConfiguration.localDefault
        Preferences.remoteConnectionConfig = (try? JSONDecoder().decode(ConnectionConfiguration.self, from: stored["remoteConnectionConfig"] as? Data ?? Data())) ?? ConnectionConfiguration.remoteDefault
        Preferences.sitemapForWatchLabel = stored["sitemapForWatchLabel"] as? String ?? "watch"
        Preferences.homeName = stored["homeName"] as? String ?? "Home"
        loadingStoredPreferences = false
        storeCurrentPreferences()
    }
}

@MainActor
public extension Preferences {
    private static func currentPreferencesDict(updatedKey: String = "", updatedValue: any Sendable = "") -> [String: any Sendable] {
        [
            "defaultView": updatedKey == "defaultView" ? updatedValue : defaultView,
            "demomode": updatedKey == "demomode" ? updatedValue : demomode,
            "realTimeSliders": updatedKey == "realTimeSliders" ? updatedValue : realTimeSliders,
            "iconType": updatedKey == "iconType" ? updatedValue : iconType,
            "defaultSitemap": updatedKey == "defaultSitemap" ? updatedValue : defaultSitemap,
            "sortSitemapsBy": updatedKey == "sortSitemapsBy" ? updatedValue : sortSitemapsBy,
            "defaultMainUIPath": updatedKey == "defaultMainUIPath" ? updatedValue : defaultMainUIPath,
            "alwaysAllowWebRTC": updatedKey == "alwaysAllowWebRTC" ? updatedValue : alwaysAllowWebRTC,
            "sitemapForWatch": updatedKey == "sitemapForWatch" ? updatedValue : sitemapForWatch,
            "localConnectionConfig": updatedKey == "localConnectionConfig" ? updatedValue : try? JSONEncoder().encode(localConnectionConfig),
            "remoteConnectionConfig": updatedKey == "remoteConnectionConfig" ? updatedValue : try? JSONEncoder().encode(remoteConnectionConfig),
            "sitemapForWatchLabel": updatedKey == "sitemapForWatchLabel" ? updatedValue : sitemapForWatchLabel,
            "homeName": updatedKey == "homeName" ? updatedValue : homeName
        ]
    }

    static func storePreferences(for settingsId: String, updatedKey: String = "", updatedValue: any Sendable = "") {
        guard !loadingStoredPreferences else { return }
        var all = storedPreferences
        if updatedKey.isEmpty {
            // store the current set preferences for the settingsId
            all[settingsId] = currentPreferencesDict()
        } else {
            // assign the current settings for this home
            var record = all[settingsId] ?? [:]
            // update just the single value
            record[updatedKey] = updatedValue
            // set the updated record back
            all[settingsId] = record
        }
        storedPreferences = all
        os_log("Stored preferences for home %{public}@", log: .default, type: .debug, settingsId)
    }

    // omitting the updatedKey will result in all settings being saved
    static func storeCurrentPreferences(updatedKey: String = "", updatedValue: any Sendable = "") {
        storePreferences(for: currentlyUsedSettings, updatedKey: updatedKey, updatedValue: updatedValue)
    }

    // helper function for when we update the remote connection cloudUserId for notifications
    static func setRemoteConnection(_ connection: ConnectionConfiguration, for settingsId: String) {
        guard let encoded = try? JSONEncoder().encode(connection) else { return }
        // Update local instance if this is the active home
        if settingsId == currentlyUsedSettings {
            remoteConnectionConfig = connection
        }
        storePreferences(for: settingsId, updatedKey: "remoteConnectionConfig", updatedValue: encoded)
    }
}

@MainActor
public extension Preferences {
    static func firstStoredSettings(where key: String, matches predicate: (Any) -> Bool) -> (id: UUID, record: [String: any Sendable])? {
        for (uuidString, record) in storedPreferences {
            guard let raw = record[key], predicate(raw),
                  let uuid = UUID(uuidString: uuidString) else { continue }
            return (uuid, record)
        }
        return nil
    }

    static func storedSettingsId(forCloudUserId id: String) -> UUID? {
        firstStoredSettings(where: "remoteConnectionConfig") { raw in
            guard
                let data = raw as? Data,
                let cfg = try? JSONDecoder().decode(ConnectionConfiguration.self, from: data)
            else { return false }
            return cfg.cloudUserId == id
        }?.id
    }
}

@MainActor
public extension Preferences {
    static func preferenceInstance(for settingsId: String) -> PreferenceInstance? {
        guard let dict = storedPreferences[settingsId], let uuid = UUID(uuidString: settingsId) else { return nil }
        return PreferenceInstance(id: uuid, dict: dict)
    }
}

// MARK: Migration

public extension Preferences {
    static func migrateUserDefaultsIfRequired() {
        guard !didMigrateToSharedDefaults else { return }

        didMigrateToSharedDefaults = true
        Preferences.localUrl = UserDefaults.standard.string(forKey: "localUrl") ?? Preferences.localUrl
        Preferences.remoteUrl = UserDefaults.standard.string(forKey: "remoteUrl") ?? Preferences.remoteUrl
        Preferences.username = UserDefaults.standard.string(forKey: "username") ?? Preferences.username
        Preferences.password = UserDefaults.standard.string(forKey: "password") ?? Preferences.password
        Preferences.alwaysSendCreds = UserDefaults.standard.object(forKey: "alwaysSendCreds") as? Bool ?? Preferences.alwaysSendCreds
        Preferences.ignoreSSL = UserDefaults.standard.object(forKey: "ignoreSSL") as? Bool ?? Preferences.ignoreSSL
        Preferences.demomode = UserDefaults.standard.object(forKey: "demomode") as? Bool ?? Preferences.demomode
        Preferences.idleOff = UserDefaults.standard.object(forKey: "idleOff") as? Bool ?? Preferences.idleOff
        Preferences.realTimeSliders = UserDefaults.standard.object(forKey: "realTimeSliders") as? Bool ?? Preferences.realTimeSliders
        Preferences.iconType = UserDefaults.standard.object(forKey: "iconType") as? Int ?? Preferences.iconType
        Preferences.defaultSitemap = UserDefaults.standard.string(forKey: "defaultSitemap") ?? Preferences.defaultSitemap
        Preferences.sendCrashReports = UserDefaults.standard.object(forKey: "sendCrashReports") as? Bool ?? Preferences.sendCrashReports
    }

    static func migrateUserDefaultsToConnectionIfRequired() {
        guard !didMigrateToConnectionConfig else { return }

        let oldLocalUrl = UserDefaults.standard.string(forKey: "localUrl") ?? Preferences.localUrl
        let oldRemoteUrl = UserDefaults.standard.string(forKey: "remoteUrl") ?? Preferences.remoteUrl
        let oldUsername = UserDefaults.standard.string(forKey: "username") ?? Preferences.username
        let oldPassword = UserDefaults.standard.string(forKey: "password") ?? Preferences.password
        let oldAlwaysSendCreds = UserDefaults.standard.object(forKey: "alwaysSendCreds") as? Bool ?? Preferences.alwaysSendCreds
        let oldIgnoreSSL = UserDefaults.standard.object(forKey: "ignoreSSL") as? Bool ?? Preferences.ignoreSSL

        // Create new configuration
        let newLocalConfiguration = ConnectionConfiguration(
            url: oldLocalUrl,
            username: "",
            password: "",
            alwaysSendBasicAuth: oldAlwaysSendCreds,
            ignoreSSL: oldIgnoreSSL,
            supportsNotifications: false,
            priority: 0
        )

        let newRemoteConfiguration = ConnectionConfiguration(
            url: oldRemoteUrl,
            username: oldUsername,
            password: oldPassword,
            alwaysSendBasicAuth: oldAlwaysSendCreds,
            ignoreSSL: oldIgnoreSSL,
            supportsNotifications: true,
            priority: 1
        )

        // Save to Preferences
        Preferences.localConnectionConfig = newLocalConfiguration
        Preferences.remoteConnectionConfig = newRemoteConfiguration
        didMigrateToConnectionConfig = true
    }
}

// MARK: All connections

public extension Preferences {
    static func getNotificationConnection(of stored: [String: Any]) -> ConnectionConfiguration? {
        let remoteConfig = stored["remoteConnectionConfig"] as? Data ?? Data()
        let remoteConnection = try? JSONDecoder().decode(ConnectionConfiguration.self, from: remoteConfig)
        return Preferences.getNotificationConnection(of: [remoteConnection])
    }

    // this will support mutliple connection configs, right now we just pass in the remote config
    static func getNotificationConnection(of connections: [ConnectionConfiguration?]) -> ConnectionConfiguration? {
        connections
            .compactMap { $0 }
            .filter { $0.supportsNotifications == true }
            .sorted { $0.priority > $1.priority }
            .first
    }

    static func getNotificationConnection() -> ConnectionConfiguration? {
        getNotificationConnection(of: [remoteConnectionConfig])
    }
}

// MARK: - Sample Codable Model

public extension ConnectionConfiguration {
    static let localDefault = ConnectionConfiguration(
        url: "https://openhab.local:8443",
        username: "",
        password: "",
        alwaysSendBasicAuth: false,
        ignoreSSL: false,
        supportsNotifications: false,
        priority: 0
    )

    static let remoteDefault = ConnectionConfiguration(
        url: "https://myopenhab.org",
        username: "",
        password: "",
        alwaysSendBasicAuth: false,
        ignoreSSL: false,
        supportsNotifications: true,
        priority: 1
    )
}
