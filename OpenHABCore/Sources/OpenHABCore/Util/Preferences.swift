// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import os.log
import UIKit

// Convenient access to UserDefaults

// Much shorter as Property Wrappers are available with Swift 5.1
// Inspired by https://www.avanderlee.com/swift/property-wrappers/
@propertyWrapper
public struct UserDefault<T> {
    let key: String
    let defaultValue: T

    public var wrappedValue: T {
        get {
            Preferences.sharedDefaults.object(forKey: key) as? T ?? defaultValue
        }
        set {
            Preferences.sharedDefaults.set(newValue, forKey: key)
        }
    }

    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
}

// It would be nice to write something like  @UserDefault @TrimmedURL ("localUrl", defaultValue: "test") static var localUrl: String
// As long as multiple property wrappers are not supported we need to add a little repetitive boiler plate code

@propertyWrapper
public struct UserDefaultURL {
    let key: String
    let defaultValue: String

    public var wrappedValue: String {
        get {
            guard let localUrl = Preferences.sharedDefaults.string(forKey: key) else { return defaultValue }
            let trimmedUri = uriWithoutTrailingSlashes(localUrl).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !trimmedUri.isValidURL { return defaultValue }
            return trimmedUri
        }
        set {
            Preferences.sharedDefaults.set(newValue, forKey: key)
        }
    }

    init(_ key: String, defaultValue: String) {
        self.key = key
        self.defaultValue = defaultValue
    }

    func uriWithoutTrailingSlashes(_ hostUri: String) -> String {
        if !hostUri.hasSuffix("/") {
            return hostUri
        }

        return String(hostUri[..<hostUri.index(before: hostUri.endIndex)])
    }
}

public enum Preferences {
    fileprivate static let sharedDefaults = UserDefaults(suiteName: "group.es.spaphone.openhab")!

    // MARK: - Public

    @UserDefaultURL("defaultView", defaultValue: "web") public static var defaultView: String
    @UserDefaultURL("localUrl", defaultValue: "") public static var localUrl: String
    @UserDefaultURL("remoteUrl", defaultValue: "https://myopenhab.org") public static var remoteUrl: String
    @UserDefault("username", defaultValue: "test") public static var username: String
    @UserDefault("password", defaultValue: "test") public static var password: String
    @UserDefault("alwaysSendCreds", defaultValue: false) public static var alwaysSendCreds: Bool
    @UserDefault("ignoreSSL", defaultValue: false) public static var ignoreSSL: Bool
    // @UserDefault("sitemapName", defaultValue: "watch") static public var sitemapName: String
    @UserDefault("demomode", defaultValue: true) public static var demomode: Bool
    @UserDefault("idleOff", defaultValue: false) public static var idleOff: Bool
    @UserDefault("realTimeSliders", defaultValue: false) public static var realTimeSliders: Bool
    @UserDefault("iconType", defaultValue: 0) public static var iconType: Int
    @UserDefault("defaultSitemap", defaultValue: "demo") public static var defaultSitemap: String
    @UserDefault("sendCrashReports", defaultValue: false) public static var sendCrashReports: Bool
    @UserDefault("sortSitemapsBy", defaultValue: 0) public static var sortSitemapsby: Int
    @UserDefault("defaultMainUIPath", defaultValue: "") public static var defaultMainUIPath: String
    @UserDefault("alwaysAllowWebRTC", defaultValue: false) public static var alwaysAllowWebRTC: Bool

    // MARK: - Private

    @UserDefault("didMigrateToSharedDefaults", defaultValue: false) private static var didMigrateToSharedDefaults: Bool
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
