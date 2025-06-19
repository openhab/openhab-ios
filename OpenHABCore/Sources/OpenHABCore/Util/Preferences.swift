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
import Foundation
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
            let localData = dict[Preferences.Key.localConnectionConfig.rawValue] as? Data,
            let remoteData = dict[Preferences.Key.remoteConnectionConfig.rawValue] as? Data,
            let localCfg = try? JSONDecoder().decode(ConnectionConfiguration.self, from: localData),
            let remoteCfg = try? JSONDecoder().decode(ConnectionConfiguration.self, from: remoteData)
        else { return nil }

        self.id = id
        defaultView = dict[Preferences.Key.defaultView.rawValue] as? String ?? "web"
        demomode = dict[Preferences.Key.demomode.rawValue] as? Bool ?? true
        realTimeSliders = dict[Preferences.Key.realTimeSliders.rawValue] as? Bool ?? false
        iconType = dict[Preferences.Key.iconType.rawValue] as? Int ?? 0
        defaultSitemap = dict[Preferences.Key.defaultSitemap.rawValue] as? String ?? "demo"
        sortSitemapsBy = dict[Preferences.Key.sortSitemapsBy.rawValue] as? Int ?? 0
        defaultMainUIPath = dict[Preferences.Key.defaultMainUIPath.rawValue] as? String ?? ""
        alwaysAllowWebRTC = dict[Preferences.Key.alwaysAllowWebRTC.rawValue] as? Bool ?? false
        sitemapForWatch = dict[Preferences.Key.sitemapForWatch.rawValue] as? String ?? "watch"
        localConnectionConfig = localCfg
        remoteConnectionConfig = remoteCfg
        sitemapForWatchLabel = dict[Preferences.Key.sitemapForWatchLabel.rawValue] as? String ?? "watch"
        homeName = dict[Preferences.Key.homeName.rawValue] as? String ?? "Home"
    }
}

@MainActor
public enum Preferences {
    public enum Key: String {
        case localUrl
        case remoteUrl
        case username
        case password
        case alwaysSendCreds
        case ignoreSSL
        case defaultView
        case demomode
        case realTimeSliders
        case iconType
        case defaultSitemap
        case sortSitemapsBy
        case defaultMainUIPath
        case alwaysAllowWebRTC
        case sitemapForWatch
        case localConnectionConfig
        case remoteConnectionConfig
        case sitemapForWatchLabel
        case homeName
        case sendCrashReports
        case idleOff
        case storedPreferences
        case currentlyUsedSettings
        case didMigrateToSharedDefaults
        case didMigrateToConnectionConfig
        case currentWebViewPath
    }

    static let sharedDefaults = UserDefaults(suiteName: "group.org.openhab.app")!

    // MARK: - Public Deprecated preferences

    @UserDefaultURL(Key.localUrl.rawValue, defaultValue: "", store: false) public static var localUrl: String
    @UserDefaultURL(Key.remoteUrl.rawValue, defaultValue: "https://myopenhab.org", store: false) public static var remoteUrl: String
    @UserDefault(Key.username.rawValue, defaultValue: "test", store: false) public static var username: String
    @UserDefault(Key.password.rawValue, defaultValue: "test", store: false) public static var password: String
    @UserDefault(Key.alwaysSendCreds.rawValue, defaultValue: false, store: false) public static var alwaysSendCreds: Bool
    @UserDefault(Key.ignoreSSL.rawValue, defaultValue: false, store: false) public static var ignoreSSL: Bool

    // MARK: - Public Home related preferences

    @UserDefaultURL(Key.defaultView.rawValue, defaultValue: "web") public static var defaultView: String
    @UserDefault(Key.demomode.rawValue, defaultValue: true) public static var demomode: Bool
    @UserDefault(Key.realTimeSliders.rawValue, defaultValue: false) public static var realTimeSliders: Bool
    @UserDefault(Key.iconType.rawValue, defaultValue: 0) public static var iconType: Int
    @UserDefault(Key.defaultSitemap.rawValue, defaultValue: "demo") public static var defaultSitemap: String
    @UserDefault(Key.sortSitemapsBy.rawValue, defaultValue: 0) public static var sortSitemapsBy: Int
    @UserDefault(Key.defaultMainUIPath.rawValue, defaultValue: "") public static var defaultMainUIPath: String
    @UserDefault(Key.alwaysAllowWebRTC.rawValue, defaultValue: false) public static var alwaysAllowWebRTC: Bool
    @UserDefault(Key.sitemapForWatch.rawValue, defaultValue: "watch") public static var sitemapForWatch: String
    @UserDefaultObject(Key.localConnectionConfig.rawValue, defaultValue: ConnectionConfiguration.localDefault) public static var localConnectionConfig: ConnectionConfiguration
    @UserDefaultObject(Key.remoteConnectionConfig.rawValue, defaultValue: ConnectionConfiguration.remoteDefault) public static var remoteConnectionConfig: ConnectionConfiguration
    @UserDefault(Key.sitemapForWatchLabel.rawValue, defaultValue: "watch") public static var sitemapForWatchLabel: String
    @UserDefault(Key.homeName.rawValue, defaultValue: "Home") public static var homeName: String

    // MARK: - Public App related preferences

    @UserDefault(Key.sendCrashReports.rawValue, defaultValue: false, store: false) public static var sendCrashReports: Bool

    @UserDefault(Key.idleOff.rawValue, defaultValue: false, store: false) public static var idleOff: Bool

    /// settings for different homes TODO come up with better name
    @UserDefault(Key.storedPreferences.rawValue, defaultValue: [:], store: false) public static var storedPreferences: [String: [String: any Sendable]]

    // MARK: - Private preferences

    /// the currently applied settings set from storedPreferences
    @UserDefault(Key.currentlyUsedSettings.rawValue, defaultValue: UUID().uuidString, store: false) public private(set) static var currentlyUsedSettings: String

    @UserDefault(Key.didMigrateToSharedDefaults.rawValue, defaultValue: false, store: false) private static var didMigrateToSharedDefaults: Bool
    @UserDefault(Key.didMigrateToConnectionConfig.rawValue, defaultValue: false, store: false) private static var didMigrateToConnectionConfig: Bool
    @UserDefault(Key.currentWebViewPath.rawValue, defaultValue: "", store: false) public static var currentWebViewPath: String

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
        Preferences.defaultView = stored[Key.defaultView.rawValue] as? String ?? "web"
        Preferences.demomode = stored[Key.demomode.rawValue] as? Bool ?? true
        Preferences.realTimeSliders = stored[Key.realTimeSliders.rawValue] as? Bool ?? false
        Preferences.iconType = stored[Key.iconType.rawValue] as? Int ?? 0
        Preferences.defaultSitemap = stored[Key.defaultSitemap.rawValue] as? String ?? "demo"
        Preferences.sortSitemapsBy = stored[Key.sortSitemapsBy.rawValue] as? Int ?? 0
        Preferences.defaultMainUIPath = stored[Key.defaultMainUIPath.rawValue] as? String ?? ""
        Preferences.alwaysAllowWebRTC = stored[Key.alwaysAllowWebRTC.rawValue] as? Bool ?? false
        Preferences.sitemapForWatch = stored[Key.sitemapForWatch.rawValue] as? String ?? "watch"
        Preferences.localConnectionConfig = (try? JSONDecoder().decode(ConnectionConfiguration.self, from: stored[Key.localConnectionConfig.rawValue] as? Data ?? Data())) ?? ConnectionConfiguration.localDefault
        Preferences.remoteConnectionConfig = (try? JSONDecoder().decode(ConnectionConfiguration.self, from: stored[Key.remoteConnectionConfig.rawValue] as? Data ?? Data())) ?? ConnectionConfiguration.remoteDefault
        Preferences.sitemapForWatchLabel = stored[Key.sitemapForWatchLabel.rawValue] as? String ?? "watch"
        Preferences.homeName = stored[Key.homeName.rawValue] as? String ?? "Home"
        loadingStoredPreferences = false
        storeCurrentPreferences()
    }
}

@MainActor
public extension Preferences {
    private static func currentPreferencesDict(updatedKey: String = "", updatedValue: any Sendable = "") -> [String: any Sendable] {
        [
            Key.defaultView.rawValue: updatedKey == Key.defaultView.rawValue ? updatedValue : defaultView,
            Key.demomode.rawValue: updatedKey == Key.demomode.rawValue ? updatedValue : demomode,
            Key.realTimeSliders.rawValue: updatedKey == Key.realTimeSliders.rawValue ? updatedValue : realTimeSliders,
            Key.iconType.rawValue: updatedKey == Key.iconType.rawValue ? updatedValue : iconType,
            Key.defaultSitemap.rawValue: updatedKey == Key.defaultSitemap.rawValue ? updatedValue : defaultSitemap,
            Key.sortSitemapsBy.rawValue: updatedKey == Key.sortSitemapsBy.rawValue ? updatedValue : sortSitemapsBy,
            Key.defaultMainUIPath.rawValue: updatedKey == Key.defaultMainUIPath.rawValue ? updatedValue : defaultMainUIPath,
            Key.alwaysAllowWebRTC.rawValue: updatedKey == Key.alwaysAllowWebRTC.rawValue ? updatedValue : alwaysAllowWebRTC,
            Key.sitemapForWatch.rawValue: updatedKey == Key.sitemapForWatch.rawValue ? updatedValue : sitemapForWatch,
            Key.localConnectionConfig.rawValue: updatedKey == Key.localConnectionConfig.rawValue ? updatedValue : try? JSONEncoder().encode(localConnectionConfig),
            Key.remoteConnectionConfig.rawValue: updatedKey == Key.remoteConnectionConfig.rawValue ? updatedValue : try? JSONEncoder().encode(remoteConnectionConfig),
            Key.sitemapForWatchLabel.rawValue: updatedKey == Key.sitemapForWatchLabel.rawValue ? updatedValue : sitemapForWatchLabel,
            Key.homeName.rawValue: updatedKey == Key.homeName.rawValue ? updatedValue : homeName
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
    static func updateRemoteConnectionConfig(_ connection: ConnectionConfiguration, for settingsId: String) {
        guard let encoded = try? JSONEncoder().encode(connection) else { return }
        // Update local instance if this is the active home
        if settingsId == currentlyUsedSettings {
            remoteConnectionConfig = connection
        }
        storePreferences(for: settingsId, updatedKey: Key.remoteConnectionConfig.rawValue, updatedValue: encoded)
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
        firstStoredSettings(where: Key.remoteConnectionConfig.rawValue) { raw in
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
        Preferences.localUrl = UserDefaults.standard.string(forKey: Key.localUrl.rawValue) ?? Preferences.localUrl
        Preferences.remoteUrl = UserDefaults.standard.string(forKey: Key.remoteUrl.rawValue) ?? Preferences.remoteUrl
        Preferences.username = UserDefaults.standard.string(forKey: Key.username.rawValue) ?? Preferences.username
        Preferences.password = UserDefaults.standard.string(forKey: Key.password.rawValue) ?? Preferences.password
        Preferences.alwaysSendCreds = UserDefaults.standard.object(forKey: Key.alwaysSendCreds.rawValue) as? Bool ?? Preferences.alwaysSendCreds
        Preferences.ignoreSSL = UserDefaults.standard.object(forKey: Key.ignoreSSL.rawValue) as? Bool ?? Preferences.ignoreSSL
        Preferences.demomode = UserDefaults.standard.object(forKey: Key.demomode.rawValue) as? Bool ?? Preferences.demomode
        Preferences.idleOff = UserDefaults.standard.object(forKey: Key.idleOff.rawValue) as? Bool ?? Preferences.idleOff
        Preferences.realTimeSliders = UserDefaults.standard.object(forKey: Key.realTimeSliders.rawValue) as? Bool ?? Preferences.realTimeSliders
        Preferences.iconType = UserDefaults.standard.object(forKey: Key.iconType.rawValue) as? Int ?? Preferences.iconType
        Preferences.defaultSitemap = UserDefaults.standard.string(forKey: Key.defaultSitemap.rawValue) ?? Preferences.defaultSitemap
        Preferences.sendCrashReports = UserDefaults.standard.object(forKey: Key.sendCrashReports.rawValue) as? Bool ?? Preferences.sendCrashReports
    }

    static func migrateUserDefaultsToConnectionIfRequired() {
        guard !didMigrateToConnectionConfig else { return }

        let oldLocalUrl = UserDefaults.standard.string(forKey: Key.localUrl.rawValue) ?? Preferences.localUrl
        let oldRemoteUrl = UserDefaults.standard.string(forKey: Key.remoteUrl.rawValue) ?? Preferences.remoteUrl
        let oldUsername = UserDefaults.standard.string(forKey: Key.username.rawValue) ?? Preferences.username
        let oldPassword = UserDefaults.standard.string(forKey: Key.password.rawValue) ?? Preferences.password
        let oldAlwaysSendCreds = UserDefaults.standard.object(forKey: Key.alwaysSendCreds.rawValue) as? Bool ?? Preferences.alwaysSendCreds
        let oldIgnoreSSL = UserDefaults.standard.object(forKey: Key.ignoreSSL.rawValue) as? Bool ?? Preferences.ignoreSSL

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
        let remoteConfig = stored[Key.remoteConnectionConfig.rawValue] as? Data ?? Data()
        let remoteConnection = try? JSONDecoder().decode(ConnectionConfiguration.self, from: remoteConfig)
        return Preferences.getNotificationConnection(of: [remoteConnection])
    }

    static func getNotificationConnection(of connections: [ConnectionConfiguration?]) -> ConnectionConfiguration? {
        // These used to be chained calls, but the swift compiler was compaining about complexity
        let validConnections = connections.compactMap { $0 }
        let notificationCapable = validConnections.filter(\.supportsNotifications)
        // lower value means higher priority, 0 is primary
        let sorted = notificationCapable.sorted { $0.priority < $1.priority }
        return sorted.first
    }

    static func getNotificationConnection() -> ConnectionConfiguration? {
        getNotificationConnection(of: [remoteConnectionConfig])
    }
}

// MARK: - Sample Codable Model

public extension ConnectionConfiguration {
    static let localDefault = ConnectionConfiguration.makeDefaultLocal()
    static let remoteDefault = ConnectionConfiguration.makeDefaultRemote()
}
