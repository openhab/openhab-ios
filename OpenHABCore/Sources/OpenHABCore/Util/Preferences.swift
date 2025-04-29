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
    private let subject: CurrentValueSubject<T, Never>

    public var wrappedValue: T {
        get {
            Preferences.sharedDefaults.object(forKey: key) as? T ?? defaultValue
        }
        set {
            Preferences.sharedDefaults.set(newValue, forKey: key)
            DispatchQueue.main.async { [subject] in
                subject.send(newValue)
            }
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
        let currentValue = Preferences.sharedDefaults.object(forKey: key) as? T ?? defaultValue
        subject = CurrentValueSubject<T, Never>(currentValue)
    }
}

@propertyWrapper
public struct UserDefaultObject<T: Codable> {
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

@propertyWrapper
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

    // MARK: - Private

    @UserDefault("didMigrateToSharedDefaults", defaultValue: false) private static var didMigrateToSharedDefaults: Bool
    @UserDefault("didMigrateToConnectionConfig", defaultValue: false) private static var didMigrateToConnectionConfig: Bool
    @UserDefault("currentWebViewPath", defaultValue: "") public static var currentWebViewPath: String
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
