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
            let preferenceValue = Preferences.sharedDefaults.object(forKey: key)
            if let preferenceAsT = preferenceValue as? T {
                os_log(
                    "Preference value %{PUBLIC}@ is %{PUBLIC}@",
                    log: .default,
                    type: .debug,
                    key,
                    "\(preferenceAsT)"
                )
                return preferenceAsT
            } else {
                if let preferenceValue {
                    os_log(
                        "Preference value %{PUBLIC}@ was %{PUBLIC}@ but did not conform to %{PUBLIC}@. Replace with default value.",
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
                Preferences.sharedDefaults.set(fallback, forKey: key)
                return fallback
            }
        }
        set {
            os_log("Preference %{PUBLIC}@ will be changed to value %{PUBLIC}@", log: .default, type: .debug, key, "\(newValue)")
            Preferences.sharedDefaults.set(newValue, forKey: key)
                Preferences.change(storedPreference: key, to: newValue)
            }
            if store {
                Preferences.storeCurrentPreferences(updatedKey: key, updatedValue: newValue)
            }
            DispatchQueue.main.async { [subject] in
                subject.send(newValue)
            }
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(_ key: String, defaultValue: T, store: Bool = true) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
        let currentValue = Preferences.sharedDefaults.object(forKey: key) as? T ?? defaultValue
        subject = CurrentValueSubject<T, Never>(currentValue)
    }
}

@propertyWrapper @MainActor
public struct UserDefaultObject<T: Codable & Sendable> {
    private let key: String
    private let defaultValue: T
    private let subject: CurrentValueSubject<T, Never>

    public var wrappedValue: T {
        get {
            guard let data = Preferences.sharedDefaults.data(forKey: key),
                  let object = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return object
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                Preferences.sharedDefaults.set(encoded, forKey: key)
                // Relevant for Combine publication
                DispatchQueue.main.async { [subject] in
                    subject.send(newValue)
                }
            }
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue

        // Combine publication
        if let data = Preferences.sharedDefaults.data(forKey: key),
           let object = try? JSONDecoder().decode(T.self, from: data) {
            subject = CurrentValueSubject(object)
        } else {
            subject = CurrentValueSubject(defaultValue)
        }
    }
}

@propertyWrapper @MainActor
public struct UserDefaultURL {
    private let key: String
    private let defaultValue: String
    private let subject: CurrentValueSubject<String, Never>

    public var wrappedValue: String {
        get {
            let storedValue = Preferences.sharedDefaults.string(forKey: key) ?? defaultValue
            let trimmedUri = storedValue.removeTrailingSlashes().trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedUri.isValidURL ? trimmedUri : defaultValue
        }
        set {
            Preferences.sharedDefaults.set(newValue, forKey: key)
            Preferences.storeCurrentPreferences(updatedKey: key, updatedValue: newValue)
            let defaultValue = defaultValue
            // Trim and validate the new URL
            let trimmedUri = newValue.removeTrailingSlashes().trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { [subject] in
                if trimmedUri.isValidURL {
                    subject.send(trimmedUri)
                } else {
                    subject.send(defaultValue)
                }
            }
        }
    }

    public var projectedValue: AnyPublisher<String, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(_ key: String, defaultValue: String) {
        self.key = key
        self.defaultValue = defaultValue
        let currentValue = Preferences.sharedDefaults.string(forKey: key) ?? defaultValue
        subject = CurrentValueSubject<String, Never>(currentValue)
    }
}

@MainActor
public enum Preferences {
    static let sharedDefaults = UserDefaults(suiteName: "group.org.openhab.app")!

    // MARK: - Public

    @UserDefaultURL("defaultView", defaultValue: "web") public static var defaultView: String
    @UserDefaultURL("localUrl", defaultValue: "") public static var localUrl: String
    @UserDefaultURL("remoteUrl", defaultValue: "https://myopenhab.org") public static var remoteUrl: String
    @UserDefault("username", defaultValue: "test") public static var username: String
    @UserDefault("password", defaultValue: "test") public static var password: String
    @UserDefault("alwaysSendCreds", defaultValue: false) public static var alwaysSendCreds: Bool
    @UserDefault("ignoreSSL", defaultValue: false) public static var ignoreSSL: Bool
    @UserDefault("demomode", defaultValue: true) public static var demomode: Bool
    @UserDefault("idleOff", defaultValue: false) public static var idleOff: Bool
    @UserDefault("realTimeSliders", defaultValue: false) public static var realTimeSliders: Bool
    @UserDefault("iconType", defaultValue: 0) public static var iconType: Int
    @UserDefault("defaultSitemap", defaultValue: "demo") public static var defaultSitemap: String
    @UserDefault("sendCrashReports", defaultValue: false) public static var sendCrashReports: Bool
    @UserDefault("sortSitemapsBy", defaultValue: 0) public static var sortSitemapsby: Int
    @UserDefault("defaultMainUIPath", defaultValue: "") public static var defaultMainUIPath: String
    @UserDefault("alwaysAllowWebRTC", defaultValue: false) public static var alwaysAllowWebRTC: Bool
    @UserDefault("sitemapForWatch", defaultValue: "watch") public static var sitemapForWatch: String
    @UserDefaultObject("localConnectionConfig", defaultValue: ConnectionConfiguration.localDefault) public static var localConnectionConfig: ConnectionConfiguration
    @UserDefaultObject("remoteConnectionConfig", defaultValue: ConnectionConfiguration.remoteDefault) public static var remoteConnectionConfig: ConnectionConfiguration
    @UserDefault("sitemapForWatchLabel", defaultValue: "watch") public static var sitemapForWatchLabel: String
    @UserDefault("homeName", defaultValue: "Home") public static var homeName: String

    /// settings for different homes TODO come up with better name
    @UserDefault("storedPreferences", defaultValue: [:], store: false) public static var storedPreferences: [String: [String: Any]]

    // MARK: - Private

    /// the currently applied settings set from storedPreferences
    @UserDefault("currentlyUsedSettings", defaultValue: UUID().uuidString, store: false) private static var currentlyUsedSettings: String

    @UserDefault("didMigrateToSharedDefaults", defaultValue: false) private static var didMigrateToSharedDefaults: Bool
    @UserDefault("didMigrateToConnectionConfig", defaultValue: false) private static var didMigrateToConnectionConfig: Bool
    @UserDefault("currentWebViewPath", defaultValue: "") public static var currentWebViewPath: String
}

public extension Preferences {
    static func listStoredPreferences() -> [UUID] {
        if storedPreferences.isEmpty {
            //first time the multi-home view is entered, there might be no stored preferences, if no preference was changed since the update
            storeCurrentPreferences()
        }
        let preferenceIds = storedPreferences
            .sorted { e1, e2 in
                (e1.value["homeName"] as? String ?? "") <= (e2.value["homeName"] as? String ?? "")
            }
            .map(\.key)
        return preferenceIds.compactMap { UUID(uuidString: $0) }
    }

    static func switchCurrentlyUsedSettings(to settingsId: UUID) {
        let settingsIdString = settingsId.uuidString

        guard let stored = storedPreferences[settingsIdString] else {
            // we have not stored our settings in that list yet
            return
        }

        Preferences.currentlyUsedSettings = settingsIdString

        // TODO: not pretty to repeat everything here
        Preferences.defaultView = stored["defaultView"] as? String ?? "web"
        Preferences.localUrl = stored["localUrl"] as? String ?? ""
        Preferences.remoteUrl = stored["remoteUrl"] as? String ?? "https://myopenhab.org"
        Preferences.username = stored["username"] as? String ?? "test"
        Preferences.password = stored["password"] as? String ?? "test"
        Preferences.alwaysSendCreds = stored["alwaysSendCreds"] as? Bool ?? false
        Preferences.ignoreSSL = stored["ignoreSSL"] as? Bool ?? false
        Preferences.demomode = stored["demomode"] as? Bool ?? true
        Preferences.idleOff = stored["idleOff"] as? Bool ?? false
        Preferences.realTimeSliders = stored["realTimeSliders"] as? Bool ?? false
        Preferences.iconType = stored["iconType"] as? Int ?? 0
        Preferences.defaultSitemap = stored["defaultSitemap"] as? String ?? "demo"
        Preferences.sendCrashReports = stored["sendCrashReports"] as? Bool ?? false
        Preferences.sortSitemapsby = stored["sortSitemapsby"] as? Int ?? 0
        Preferences.defaultMainUIPath = stored["defaultMainUIPath"] as? String ?? ""
        Preferences.alwaysAllowWebRTC = stored["alwaysAllowWebRTC"] as? Bool ?? false
        Preferences.sitemapForWatch = stored["sitemapForWatch"] as? String ?? "watch"
        Preferences.homeName = stored["homeName"] as? String ?? "Home"
    }

    static func storeCurrentPreferences(updatedKey: String = "", updatedValue: Any = "") {
        // TODO: not pretty to repeat everything here
        var stored = storedPreferences
        stored[currentlyUsedSettings] = [
            "defaultView": updatedKey == "defaultView" ? updatedValue : Preferences.defaultView,
            "localUrl": updatedKey == "localUrl" ? updatedValue : Preferences.localUrl,
            "remoteUrl": updatedKey == "remoteUrl" ? updatedValue : Preferences.remoteUrl,
            "username": updatedKey == "username" ? updatedValue : Preferences.username,
            "password": updatedKey == "password" ? updatedValue : Preferences.password,
            "alwaysSendCreds": updatedKey == "alwaysSendCreds" ? updatedValue : Preferences.alwaysSendCreds,
            "ignoreSSL": updatedKey == "ignoreSSL" ? updatedValue : Preferences.ignoreSSL,
            "demomode": updatedKey == "demomode" ? updatedValue : Preferences.demomode,
            "idleOff": updatedKey == "idleOff" ? updatedValue : Preferences.idleOff,
            "realTimeSliders": updatedKey == "realTimeSliders" ? updatedValue : Preferences.realTimeSliders,
            "iconType": updatedKey == "iconType" ? updatedValue : Preferences.iconType,
            "defaultSitemap": updatedKey == "defaultSitemap" ? updatedValue : Preferences.defaultSitemap,
            "sendCrashReports": updatedKey == "sendCrashReports" ? updatedValue : Preferences.sendCrashReports,
            "sortSitemapsby": updatedKey == "sortSitemapsby" ? updatedValue : Preferences.sortSitemapsby,
            "defaultMainUIPath": updatedKey == "defaultMainUIPath" ? updatedValue : Preferences.defaultMainUIPath,
            "alwaysAllowWebRTC": updatedKey == "alwaysAllowWebRTC" ? updatedValue : Preferences.alwaysAllowWebRTC,
            "sitemapForWatch": updatedKey == "sitemapForWatch" ? updatedValue : Preferences.sitemapForWatch,
            "homeName": updatedKey == "homeName" ? updatedValue : Preferences.homeName
        ]
        storedPreferences = stored
    }
}

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
            priority: 0
        )

        let newRemoteConfiguration = ConnectionConfiguration(
            url: oldRemoteUrl,
            username: oldUsername,
            password: oldPassword,
            alwaysSendBasicAuth: oldAlwaysSendCreds,
            ignoreSSL: oldIgnoreSSL,
            priority: 1
        )

        // Save to Preferences
        Preferences.localConnectionConfig = newLocalConfiguration
        Preferences.remoteConnectionConfig = newRemoteConfiguration
        didMigrateToConnectionConfig = true
    }
}

public extension Preferences {
    static func getLowestPriorityOpenHABConnection() -> ConnectionConfiguration? {
        let allConnections = [localConnectionConfig, remoteConnectionConfig]

        return allConnections
            .filter { $0.url.contains("openhab.org") }
            .sorted { $0.priority < $1.priority }
            .first
    }
}

// MARK: - Sample Codable Model

public extension ConnectionConfiguration {
    static let localDefault = ConnectionConfiguration(
        url: "http://192.168.1.1:8080",
        username: "",
        password: "",
        alwaysSendBasicAuth: false,
        ignoreSSL: false,
        priority: 0
    )

    static let remoteDefault = ConnectionConfiguration(
        url: "https://myopenhab.org",
        username: "",
        password: "",
        alwaysSendBasicAuth: false,
        ignoreSSL: false,
        priority: 1
    )
}
