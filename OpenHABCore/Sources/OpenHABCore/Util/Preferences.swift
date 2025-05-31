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

import Combine
import os.log
import UIKit

@propertyWrapper
public struct UserDefault<T> {
    private let key: String
    private let defaultValue: T
    private let store: Bool
    private let subject: CurrentValueSubject<T, Never>

    public var wrappedValue: T {
        get {
            let value = Preferences.sharedDefaults.object(forKey: key) as? T ?? defaultValue
            return value
        }
        set {
            Preferences.sharedDefaults.set(newValue, forKey: key)
            if store {
                Preferences.storeCurrentPreferences()
            }
            let subject = subject
            DispatchQueue.main.async {
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

@propertyWrapper
public struct UserDefaultURL {
    private let key: String
    private let defaultValue: String
    private let subject: CurrentValueSubject<String, Never>

    public var wrappedValue: String {
        get {
            let storedValue = Preferences.sharedDefaults.string(forKey: key) ?? defaultValue
            let trimmedUri = uriWithoutTrailingSlashes(storedValue).trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedUri.isValidURL ? trimmedUri : defaultValue
        }
        set {
            Preferences.sharedDefaults.set(newValue, forKey: key)
            Preferences.storeCurrentPreferences()
            let subject = subject
            let defaultValue = defaultValue
            // Trim and validate the new URL
            let trimmedUri = uriWithoutTrailingSlashes(newValue).trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
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

    private func uriWithoutTrailingSlashes(_ hostUri: String) -> String {
        if hostUri.hasSuffix("/") {
            return String(hostUri[..<hostUri.index(before: hostUri.endIndex)])
        }
        return hostUri
    }
}

public enum Preferences {
    fileprivate static let sharedDefaults = UserDefaults(suiteName: "group.org.openhab.app")!

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
    @UserDefault("homeName", defaultValue: "Home") public static var homeName: String

    /// settings for different homes TODO come up with better name
    @UserDefault("storedPreferences", defaultValue: [:], store: false) public static var storedPreferences: [String: NSDictionary]

    // MARK: - Private

    /// the currently applied settings set from storedPreferences
    @UserDefault("currentlyUsedSettings", defaultValue: UUID().uuidString, store: false) private static var currentlyUsedSettings: String

    @UserDefault("didMigrateToSharedDefaults", defaultValue: false) private static var didMigrateToSharedDefaults: Bool
}

public extension Preferences {
    static func listStoredPreferences() -> [UUID] {
        initializeStoredPreferences()
        let preferenceIds = storedPreferences
            .sorted { e1, e2 in
                (e1.value["homeName"] as? String ?? "") <= (e2.value["homeName"] as? String ?? "")
            }
            .map(\.key)
        return preferenceIds.compactMap { UUID(uuidString: $0) }
    }

    static func switchCurrentlyUsedSettings(to settingsId: UUID) {
        initializeStoredPreferences()

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

    private static func initializeStoredPreferences() {
        if storedPreferences.isEmpty {
            storeCurrentPreferences()
        }
    }

    static func storeCurrentPreferences() {
        // TODO: not pretty to repeat everything here
        var stored = storedPreferences
        stored[currentlyUsedSettings] = [
            "defaultView": Preferences.defaultView,
            "localUrl": Preferences.localUrl,
            "remoteUrl": Preferences.remoteUrl,
            "username": Preferences.username,
            "password": Preferences.password,
            "alwaysSendCreds": Preferences.alwaysSendCreds,
            "ignoreSSL": Preferences.ignoreSSL,
            "demomode": Preferences.demomode,
            "idleOff": Preferences.idleOff,
            "realTimeSliders": Preferences.realTimeSliders,
            "iconType": Preferences.iconType,
            "defaultSitemap": Preferences.defaultSitemap,
            "sendCrashReports": Preferences.sendCrashReports,
            "sortSitemapsby": Preferences.sortSitemapsby,
            "defaultMainUIPath": Preferences.defaultMainUIPath,
            "alwaysAllowWebRTC": Preferences.alwaysAllowWebRTC,
            "sitemapForWatch": Preferences.sitemapForWatch,
            "homeName": Preferences.homeName
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
}
