// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

//
//  UserDefaults.swift
//
//  Created by Dirk Hermanns on 01.06.18.
//  Copyright © 2018 private. All rights reserved.
//
import os.log
import UIKit

let defaultValues = ["username": "test", "password": "test", "sitemapName": "watch", "defaultSitemap": "demo"]

// Convenient access to UserDefaults
// Much shorter but to be reworked when Property Wrappers are available
struct Preferences {
    static private let defaults = UserDefaults.standard

    static var localUrl: String {
        get {
            guard let localUrl = defaults.string(forKey: #function) else { return "" }
            let trimmedUri = uriWithoutTrailingSlashes(localUrl).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !validateUrl(trimmedUri) { return "" }
            return trimmedUri
        }
        set { defaults.setValue(newValue, forKey: #function) }
    }

    static var remoteUrl: String {
        get {
            guard let localUrl = defaults.string(forKey: #function) else { return "https://openhab.org:8444" }
            let trimmedUri = uriWithoutTrailingSlashes(localUrl).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !validateUrl(trimmedUri) { return "" }
            return trimmedUri
        }
        set { defaults.setValue(newValue, forKey: #function) }
    }

    static var username: String {
        get { guard let string = defaults.string(forKey: #function) else { return defaultValues[#function]! }
            return string
        }
        set { defaults.setValue(newValue, forKey: #function) }
    }

    static var password: String {
        get { guard let string = defaults.string(forKey: #function) else { return defaultValues[#function]! }
            return string
        }
        set { defaults.setValue(newValue, forKey: #function) }
    }

    static var ignoreSSL: Bool {
        get { defaults.bool(forKey: #function) }
        set { defaults.setValue(newValue, forKey: #function) }
    }

    static var sitemapName: String {
        get { guard let string = defaults.string(forKey: #function) else { return defaultValues[#function]! }
            return string
        }
        set { defaults.setValue(newValue, forKey: #function) }
    }

    static var demomode: Bool {
        get { defaults.bool(forKey: #function) }
        set { defaults.setValue(newValue, forKey: #function) }
    }

    static var idleOff: Bool {
        get { defaults.bool(forKey: #function) }
        set { defaults.setValue(newValue, forKey: #function) }
    }

    static var iconType: Int {
        get { defaults.integer(forKey: #function) }
        set { defaults.setValue(newValue, forKey: #function) }
    }

    static var defaultSitemap: String {
        get { guard let string = defaults.string(forKey: #function) else { return defaultValues[#function]! }
            return string
        }
        set { defaults.setValue(newValue, forKey: #function) }
    }

    static func readActiveUrl() -> String {
        if Preferences.remoteUrl != "" {
            return Preferences.remoteUrl
        }
        return Preferences.localUrl
    }

    fileprivate static func validateUrl(_ stringURL: String) -> Bool {
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
