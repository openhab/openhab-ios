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
    // Optional so a payload from a mismatched app version still decodes; the
    // watch resolves them to defaults (`.name` / `.label`) when absent.
    public var sitemapNameLabelDisplayMode: Int?
    public var sortSitemapsBy: Int?
    public var localConnectionConfiguration: ConnectionConfiguration?
    public var remoteConnectionConfiguration: ConnectionConfiguration?

    public init(localUrl: String, remoteUrl: String, username: String, password: String, alwaysSendCreds: Bool, defaultSitemap: String, ignoreSSL: Bool, sitemapForWatch: String, sitemapForWatchLabel: String, iconType: Int, demoMode: Bool, sitemapNameLabelDisplayMode: Int? = nil, sortSitemapsBy: Int? = nil, localConnectionConfiguration: ConnectionConfiguration? = nil, remoteConnectionConfiguration: ConnectionConfiguration? = nil) {
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
        self.sitemapNameLabelDisplayMode = sitemapNameLabelDisplayMode
        self.sortSitemapsBy = sortSitemapsBy
        self.localConnectionConfiguration = localConnectionConfiguration
        self.remoteConnectionConfiguration = remoteConnectionConfiguration
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
