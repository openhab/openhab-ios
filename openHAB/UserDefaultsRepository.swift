// Copyright (c) 2010-2019 Contributors to the openHAB project
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
struct Preferences {
    // Much shorter as Property Wrappers are available with Swift 5.1
    // Inspired by https://www.avanderlee.com/swift/property-wrappers/
    @propertyWrapper
    struct UserDefault<T> {
        let key: String
        let defaultValue: T

        init(_ key: String, defaultValue: T) {
            self.key = key
            self.defaultValue = defaultValue
        }

        var wrappedValue: T {
            get {
                return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
            }
            set {
                UserDefaults.standard.set(newValue, forKey: key)
            }
        }
    }

    // It would be nice to write something like  @UserDefault @TrimmedURL ("localUrl", defaultValue: "test") static var localUrl: String
    // As long as multiple property wrappers are not supported we need to add a little repetitive boiler plate code

    @propertyWrapper
    struct UserDefaultURL {
        let key: String
        let defaultValue: String

        init(_ key: String, defaultValue: String) {
            self.key = key
            self.defaultValue = defaultValue
        }

        var wrappedValue: String {
            get {
                guard let localUrl = UserDefaults.standard.string(forKey: key) else { return defaultValue }
                let trimmedUri = uriWithoutTrailingSlashes(localUrl).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !validateUrl(trimmedUri) { return defaultValue }
                return trimmedUri
            }
            set {
                UserDefaults.standard.set(newValue, forKey: key)
            }
        }
    }

    static private let defaults = UserDefaults.standard

    @UserDefaultURL("localUrl", defaultValue: "") static var localUrl: String
    @UserDefaultURL("remoteUrl", defaultValue: "https://openhab.org:8444") static var remoteUrl: String

    @UserDefault("username", defaultValue: "test") static var username: String
    @UserDefault("password", defaultValue: "test") static var password: String
    @UserDefault("ignoreSSL", defaultValue: false) static var ignoreSSL: Bool
    @UserDefault("sitemapName", defaultValue: "watch") static var sitemapName: String
    @UserDefault("demomode", defaultValue: true) static var demomode: Bool
    @UserDefault("idleOff", defaultValue: false) static var idleOff: Bool
    @UserDefault("iconType", defaultValue: 0) static var iconType: Int
    @UserDefault("defaultSitemap", defaultValue: "demo") static var defaultSitemap: String

    static func readActiveUrl() -> String {
        if Preferences.remoteUrl != "" {
            return Preferences.remoteUrl
        }
        return Preferences.localUrl
    }

    private static func validateUrl(_ stringURL: String) -> Bool {
        // return nil if the URL has not a valid format
        let url: URL? = URL(string: stringURL)
        return url != nil
    }

    static func uriWithoutTrailingSlashes(_ hostUri: String) -> String {
        if !hostUri.hasSuffix("/") {
            return hostUri
        }

        return String(hostUri[..<hostUri.index(before: hostUri.endIndex)])
    }
}
