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
    private let isHomeProperty: Bool
    private let subject: CurrentValueSubject<T, Never>

    public var wrappedValue: T {
        get {
            Preferences.getPreference(key: key, defaultValue: defaultValue, encoder: { $0 }, decoder: { $0 as? T })
        }
        set {
            Preferences.preferenceChanged(newValue: newValue, key: key, isHomeProperty: isHomeProperty, subject: subject) { $0 }
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(_ key: String, defaultValue: T, isHomeProperty: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
        self.isHomeProperty = isHomeProperty
        let currentValue = Preferences.getPreference(key: key, defaultValue: defaultValue, encoder: { $0 }, decoder: { $0 as? T })
        subject = CurrentValueSubject<T, Never>(currentValue)
    }
}

@propertyWrapper @MainActor
public struct UserDefaultObject<T: Codable & Sendable> {
    private let key: String
    private let defaultValue: T
    private let isHomeProperty: Bool
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
            Preferences.preferenceChanged(newValue: newValue, key: key, isHomeProperty: isHomeProperty, subject: subject, converter: objectEncoder)
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    init(_ key: String, defaultValue: T, isHomeProperty: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
        self.isHomeProperty = isHomeProperty

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
    private let isHomeProperty: Bool
    private let subject: CurrentValueSubject<String, Never>

    public var wrappedValue: String {
        get {
            Preferences.getPreference(key: key, defaultValue: defaultValue, encoder: UserDefaultURL.urlSanitizer, decoder: UserDefaultURL.urlConverter)
        }
        set {
            Preferences.preferenceChanged(newValue: newValue, key: key, isHomeProperty: isHomeProperty, subject: subject, sanitize: UserDefaultURL.urlSanitizer) { $0 }
        }
    }

    public var projectedValue: AnyPublisher<String, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(_ key: String, defaultValue: String, isHomeProperty: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
        self.isHomeProperty = isHomeProperty
        let currentValue = Preferences.getPreference(key: key, defaultValue: defaultValue, encoder: { $0 }, decoder: UserDefaultURL.urlConverter)
        subject = CurrentValueSubject<String, Never>(currentValue)
    }
}

@MainActor
public struct HomePreferences: Codable {
    public let id: UUID
    public var defaultView: String = "web"
    public var demomode: Bool = true
    public var realTimeSliders: Bool = false
    public var iconType: Int = 0
    public var defaultSitemap: String = "demo"
    public var sortSitemapsBy: Int = 0
    public var defaultMainUIPath: String = ""
    public var alwaysAllowWebRTC: Bool = false
    public var sitemapForWatch: String = "watch"
    public var localConnectionConfig: ConnectionConfiguration = .localDefault
    public var remoteConnectionConfig: ConnectionConfiguration = .remoteDefault
    public var sitemapForWatchLabel: String = "watch"
    public var homeName: String = "Home"

    fileprivate init(id: UUID) {
        self.id = id
    }
}

@MainActor
public enum Preferences {
    /// the currently applied settings set from storedPreferences
    @UserDefaultObject("currentHomePreferences", defaultValue: HomePreferences(id: UUID())) public private(set) static var currentHomePreferences: HomePreferences

    @UserDefault("sendCrashReports", defaultValue: false) public static var sendCrashReports: Bool

    @UserDefault("idleOff", defaultValue: false) public static var idleOff: Bool

    @UserDefault("currentWebViewPath", defaultValue: "") public static var currentWebViewPath: String
    /// settings for different homes TODO come up with better name
    @UserDefaultObject("storedPreferences", defaultValue: [:]) public private(set) static var storedPreferences: [UUID: HomePreferences]
    /// the currently applied settings set from storedPreferences
    @UserDefault("currentlyUsedSettings", defaultValue: UUID().uuidString) private static var currentlyUsedSettings: String
    @UserDefault("didMigrateToSharedDefaults", defaultValue: false) private static var didMigrateToSharedDefaults: Bool
    @UserDefault("didMigrateToConnectionConfig", defaultValue: false) private static var didMigrateToConnectionConfig: Bool
    private static var loadingStoredPreferences = false
}

// MARK: Retrieving preference from user defaults, reacting to preference change

extension Preferences {
    static let sharedDefaults = UserDefaults(suiteName: "group.org.openhab.app")!

    fileprivate static func getPreference<T>(key: String, defaultValue: T, encoder: (T) -> (some Sendable)?, decoder: (Any?) -> T?) -> T {
        let preferenceValue = sharedDefaults.object(forKey: key)
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
            sharedDefaults.set(encoder(fallback), forKey: key)
            return fallback
        }
    }

    fileprivate static func preferenceChanged<T>(newValue: T, key: String, isHomeProperty: Bool, subject: CurrentValueSubject<T, Never>, sanitize: (T) -> (T?) = { $0 }, converter: (T) -> (some Sendable)?) {
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
        sharedDefaults.set(convertedValue, forKey: key)

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
                e1.value.homeName <= e2.value.homeName
            }
            .map(\.key)
        return preferenceIds
    }

    static func getCurrentlyUsedSettings() -> UUID {
        guard let currentPreferenceUUID = UUID(uuidString: currentlyUsedSettings) else {
            fatalError("currentlyUsedSettings must be a UUID, but was \(currentlyUsedSettings)")
        }
        return currentPreferenceUUID
    }

    static func createAndLoadNewStoredSettings(homeName: String) {
        currentlyUsedSettings = UUID().uuidString
        var newHomePreferences = HomePreferences(id: getCurrentlyUsedSettings())
        newHomePreferences.homeName = homeName
        loadSettings(stored: newHomePreferences)
    }

    static func renameHome(_ settingsId: UUID, newHomeName: String) {
        var stored = storedPreferences
        stored[settingsId]?.homeName = newHomeName
        storedPreferences = stored
    }

    static func deleteStoredSettings(_ settingsId: UUID) {
        guard settingsId != getCurrentlyUsedSettings() else {
            // cannot remove current home
            return
        }
        var stored = storedPreferences
        stored.removeValue(forKey: settingsId)
        storedPreferences = stored
    }

    static func switchCurrentlyUsedSettings(to settingsId: UUID) {
        guard let stored = storedPreferences[settingsId] else {
            // we have not stored our settings in that list yet
            return
        }

        currentlyUsedSettings = settingsId.uuidString

        loadSettings(stored: stored)
    }

    private static func initializeStoredPreferences() {
        if storedPreferences.isEmpty {
            // first there might be no stored preferences, if no preference was changed since the update
            storeCurrentHomePreferences()
        }
    }

    private static func loadSettings(stored: HomePreferences) {
        loadingStoredPreferences = true
        Preferences.currentHomePreferences = stored
        loadingStoredPreferences = false
        storeCurrentHomePreferences() // store home settings in case they were not yet there
    }

    private static func storeCurrentHomePreferences() {
        var all = storedPreferences
        let homeId = Preferences.getCurrentlyUsedSettings()
        all[homeId] = Preferences.currentHomePreferences
        storedPreferences = all
        os_log("Stored preferences for current home %{public}@", log: .default, type: .debug, homeId.uuidString)
    }

    static func changeCurrentHomePreferences(modificationFunction: (inout HomePreferences) -> Void) {
        var homePreferences = currentHomePreferences
        modificationFunction(&homePreferences)
        currentHomePreferences = homePreferences
        storeCurrentHomePreferences()
    }

    // helper function for when we update the remote connection cloudUserId for notifications
    static func setCloudUserId(_ cloudUserId: String?, for homeId: UUID) {
        if homeId == getCurrentlyUsedSettings() {
            changeCurrentHomePreferences { homePreferences in
                homePreferences.remoteConnectionConfig.cloudUserId = cloudUserId
            }
        } else {
            var storedHomes = storedPreferences
            var home = storedHomes[homeId]
            home?.remoteConnectionConfig.cloudUserId = cloudUserId
            storedHomes[homeId] = home
            storedPreferences = storedHomes
        }
    }
}

@MainActor
public extension Preferences {
    static func firstStoredSettings(where predicate: (HomePreferences) -> Bool) -> (id: UUID, record: HomePreferences)? {
        for (uuid, record) in storedPreferences {
            guard predicate(record) else { continue }
            return (uuid, record)
        }
        return nil
    }

    static func storedSettingsId(forCloudUserId id: String) -> UUID? {
        firstStoredSettings { homePreferences in
            homePreferences.remoteConnectionConfig.cloudUserId == id
        }?.id
    }
}

// MARK: Migration

public extension Preferences {
    static func migratePreferences() {
        initializeStoredPreferences()
        migrateToSharedDefaultsIfRequired()
        migrateToConnectionConfigIfRequired()
    }

    private static func migrateToSharedDefaultsIfRequired() {
        guard !didMigrateToSharedDefaults else { return }

        var currentHomePreferences = Preferences.currentHomePreferences

        currentHomePreferences.localConnectionConfig.url = UserDefaults.standard.string(forKey: "localUrl") ?? currentHomePreferences.localConnectionConfig.url
        currentHomePreferences.localConnectionConfig.alwaysSendBasicAuth = UserDefaults.standard.object(forKey: "alwaysSendCreds") as? Bool ?? currentHomePreferences.localConnectionConfig.alwaysSendBasicAuth
        currentHomePreferences.localConnectionConfig.ignoreSSL = UserDefaults.standard.object(forKey: "ignoreSSL") as? Bool ?? currentHomePreferences.localConnectionConfig.ignoreSSL
        currentHomePreferences.remoteConnectionConfig.url = UserDefaults.standard.string(forKey: "remoteUrl") ?? currentHomePreferences.remoteConnectionConfig.url
        currentHomePreferences.remoteConnectionConfig.username = UserDefaults.standard.string(forKey: "username") ?? currentHomePreferences.remoteConnectionConfig.username
        currentHomePreferences.remoteConnectionConfig.password = UserDefaults.standard.string(forKey: "password") ?? currentHomePreferences.remoteConnectionConfig.password
        currentHomePreferences.remoteConnectionConfig.alwaysSendBasicAuth = UserDefaults.standard.object(forKey: "alwaysSendCreds") as? Bool ?? currentHomePreferences.remoteConnectionConfig.alwaysSendBasicAuth
        currentHomePreferences.remoteConnectionConfig.ignoreSSL = UserDefaults.standard.object(forKey: "ignoreSSL") as? Bool ?? currentHomePreferences.remoteConnectionConfig.ignoreSSL
        currentHomePreferences.demomode = UserDefaults.standard.object(forKey: "demomode") as? Bool ?? currentHomePreferences.demomode
        currentHomePreferences.realTimeSliders = UserDefaults.standard.object(forKey: "realTimeSliders") as? Bool ?? currentHomePreferences.realTimeSliders
        currentHomePreferences.iconType = UserDefaults.standard.object(forKey: "iconType") as? Int ?? currentHomePreferences.iconType
        currentHomePreferences.defaultSitemap = UserDefaults.standard.string(forKey: "defaultSitemap") ?? currentHomePreferences.defaultSitemap

        Preferences.currentHomePreferences = currentHomePreferences
        Preferences.idleOff = UserDefaults.standard.object(forKey: "idleOff") as? Bool ?? Preferences.idleOff
        Preferences.sendCrashReports = UserDefaults.standard.object(forKey: "sendCrashReports") as? Bool ?? Preferences.sendCrashReports

        didMigrateToSharedDefaults = true
    }

    private static func migrateToConnectionConfigIfRequired() {
        guard !didMigrateToConnectionConfig else { return }

        migrateToSharedDefaultsIfRequired()

        let oldLocalUrl = Preferences.sharedDefaults.string(forKey: "localUrl")
        let oldRemoteUrl = Preferences.sharedDefaults.string(forKey: "remoteUrl")
        let oldUsername = Preferences.sharedDefaults.string(forKey: "username")
        let oldPassword = Preferences.sharedDefaults.string(forKey: "password")
        let oldAlwaysSendCreds = Preferences.sharedDefaults.object(forKey: "alwaysSendCreds") as? Bool
        let oldIgnoreSSL = Preferences.sharedDefaults.object(forKey: "ignoreSSL") as? Bool

        // Create new configuration
        var newLocalConfiguration = Preferences.currentHomePreferences.localConnectionConfig
        newLocalConfiguration.url = oldLocalUrl ?? newLocalConfiguration.url
        newLocalConfiguration.alwaysSendBasicAuth = oldAlwaysSendCreds ?? newLocalConfiguration.alwaysSendBasicAuth
        newLocalConfiguration.ignoreSSL = oldIgnoreSSL ?? newLocalConfiguration.ignoreSSL

        var newRemoteConfiguration = Preferences.currentHomePreferences.remoteConnectionConfig
        newRemoteConfiguration.url = oldRemoteUrl ?? newRemoteConfiguration.url
        newRemoteConfiguration.username = oldUsername ?? newRemoteConfiguration.username
        newRemoteConfiguration.password = oldPassword ?? newRemoteConfiguration.password
        newRemoteConfiguration.alwaysSendBasicAuth = oldAlwaysSendCreds ?? newRemoteConfiguration.alwaysSendBasicAuth
        newRemoteConfiguration.ignoreSSL = oldIgnoreSSL ?? newRemoteConfiguration.ignoreSSL

        // Save to Preferences
        var currentHomePreferences = Preferences.currentHomePreferences
        currentHomePreferences.localConnectionConfig = newLocalConfiguration
        currentHomePreferences.remoteConnectionConfig = newRemoteConfiguration

        Preferences.currentHomePreferences = currentHomePreferences

        didMigrateToConnectionConfig = true
    }
}

// MARK: All connections

public extension Preferences {
    static func getNotificationConnection() -> ConnectionConfiguration? {
        getNotificationConnection(of: [Preferences.currentHomePreferences.remoteConnectionConfig])
    }

    static func getNotificationConnection(of homeConfig: HomePreferences) -> ConnectionConfiguration? {
        getNotificationConnection(of: [homeConfig.remoteConnectionConfig])
    }

    // this will support mutliple connection configs, right now we just pass in the remote config
    static func getNotificationConnection(of connections: [ConnectionConfiguration?]) -> ConnectionConfiguration? {
        connections
            .compactMap { $0 }
            .filter { $0.supportsNotifications == true }
            .sorted { $0.priority > $1.priority }
            .first
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
