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
    public var localUrl: String
    public var remoteUrl: String
    public var username: String
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

    public init(localUrl: String, remoteUrl: String, username: String, password: String, alwaysSendCreds: Bool, defaultSitemap: String, ignoreSSL: Bool, sitemapForWatch: String, sitemapForWatchLabel: String, iconType: Int, demoMode: Bool, localConnectionConfiguration: ConnectionConfiguration? = nil, remoteConnectionConfiguration: ConnectionConfiguration? = nil, allHomes: [String: HomePreferences]? = nil) {
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
