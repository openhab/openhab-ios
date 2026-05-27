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

import Foundation
import os.log

public struct WatchPreferences: Codable {
    enum CodingKeys: String, CodingKey {
        case localUrl, remoteUrl, username, password, alwaysSendCreds, defaultSitemap
        case ignoreSSL, sitemapForWatch, sitemapForWatchLabel, iconType, demoMode
        case localConnectionConfiguration, remoteConnectionConfiguration
        case localUsername, localPassword
        case allHomes
    }

    public var localUrl: String
    public var remoteUrl: String
    /// Remote connection username (top-level for backward compatibility).
    public var username: String
    /// Remote connection password (top-level for backward compatibility).
    public var password: String
    public var alwaysSendCreds: Bool
    public var defaultSitemap: String
    public var ignoreSSL: Bool
    public var sitemapForWatch: String
    public var sitemapForWatchLabel: String
    public var iconType: Int
    public var demoMode: Bool
    public var localConnectionConfiguration: ConnectionConfiguration?
    public var remoteConnectionConfiguration: ConnectionConfiguration?
    /// All homes keyed by UUID string. Nil when sent by an older app version that predates this field.
    public var allHomes: [String: HomePreferences]?
    /// Local connection username. Old senders omit this field; defaults to empty string.
    public var localUsername: String
    /// Local connection password. Old senders omit this field; defaults to empty string.
    public var localPassword: String

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        localUrl = try c.decode(String.self, forKey: .localUrl)
        remoteUrl = try c.decode(String.self, forKey: .remoteUrl)
        username = try c.decode(String.self, forKey: .username)
        password = try c.decode(String.self, forKey: .password)
        alwaysSendCreds = try c.decode(Bool.self, forKey: .alwaysSendCreds)
        defaultSitemap = try c.decode(String.self, forKey: .defaultSitemap)
        ignoreSSL = try c.decode(Bool.self, forKey: .ignoreSSL)
        sitemapForWatch = try c.decode(String.self, forKey: .sitemapForWatch)
        sitemapForWatchLabel = try c.decode(String.self, forKey: .sitemapForWatchLabel)
        iconType = try c.decode(Int.self, forKey: .iconType)
        demoMode = try c.decode(Bool.self, forKey: .demoMode)
        localConnectionConfiguration = try c.decodeIfPresent(ConnectionConfiguration.self, forKey: .localConnectionConfiguration)
        remoteConnectionConfiguration = try c.decodeIfPresent(ConnectionConfiguration.self, forKey: .remoteConnectionConfiguration)
        localUsername = try c.decodeIfPresent(String.self, forKey: .localUsername) ?? ""
        localPassword = try c.decodeIfPresent(String.self, forKey: .localPassword) ?? ""
        allHomes = try c.decodeIfPresent([String: HomePreferences].self, forKey: .allHomes)
    }

    public init(localUrl: String, remoteUrl: String, username: String, password: String, alwaysSendCreds: Bool, defaultSitemap: String, ignoreSSL: Bool, sitemapForWatch: String, sitemapForWatchLabel: String, iconType: Int, demoMode: Bool, localConnectionConfiguration: ConnectionConfiguration? = nil, remoteConnectionConfiguration: ConnectionConfiguration? = nil, allHomes: [String: HomePreferences]? = nil, localUsername: String = "", localPassword: String = "") {
        self.localUrl = localUrl
        self.remoteUrl = remoteUrl
        self.username = username
        self.password = password
        self.alwaysSendCreds = alwaysSendCreds
        self.defaultSitemap = defaultSitemap
        self.ignoreSSL = ignoreSSL
        self.sitemapForWatch = sitemapForWatch
        self.sitemapForWatchLabel = sitemapForWatchLabel
        self.iconType = iconType
        self.demoMode = demoMode
        self.localConnectionConfiguration = localConnectionConfiguration
        self.remoteConnectionConfiguration = remoteConnectionConfiguration
        self.allHomes = allHomes
        self.localUsername = localUsername
        self.localPassword = localPassword
    }

    public func encodedWatchPreferences() -> [String: Data] {
        do {
            let data = try JSONEncoder().encode(self)
            return ["watchPreferences": data]
        } catch {
            Logger.preferences.error("Failed to encode WatchPreferences: \(error.localizedDescription)")
            return [:]
        }
    }
}
