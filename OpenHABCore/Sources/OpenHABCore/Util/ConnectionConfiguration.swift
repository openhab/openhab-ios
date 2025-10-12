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

import Foundation

public struct ConnectionPayload: Codable {
    public var local: ConnectionConfiguration
    public var remote: ConnectionConfiguration
}

public struct ConnectionConfiguration: Hashable, Sendable, Codable, Equatable {
    // 🔹 Coding keys for manual encoding/decoding
    private enum CodingKeys: String, CodingKey {
        case url, username, password, alwaysSendBasicAuth, ignoreSSL, supportsNotifications, priority, cloudUserId
    }

    public var url: String
    public var username: String
    public var password: String
    public var alwaysSendBasicAuth: Bool
    public var ignoreSSL: Bool
    public var priority: Int // Lower is higher priority, 0 is primary
    public var supportsNotifications = false
    public var cloudUserId: String?

    public init(url: String, username: String, password: String, alwaysSendBasicAuth: Bool = false, ignoreSSL: Bool = false, supportsNotifications: Bool = false, priority: Int = 10) {
        self.url = ConnectionConfiguration.normalizeURL(url)
        self.username = username
        self.password = password
        self.alwaysSendBasicAuth = alwaysSendBasicAuth
        self.ignoreSSL = ignoreSSL
        self.priority = priority
        self.supportsNotifications = supportsNotifications
    }

    // 🔹 Ensure normalization on decoding
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawURL = try container.decode(String.self, forKey: .url) // Decode raw URL
        url = ConnectionConfiguration.normalizeURL(rawURL) // Normalize it
        username = try container.decode(String.self, forKey: .username)
        password = try container.decode(String.self, forKey: .password)
        alwaysSendBasicAuth = try container.decode(Bool.self, forKey: .alwaysSendBasicAuth)
        ignoreSSL = try container.decode(Bool.self, forKey: .ignoreSSL)
        supportsNotifications = try container.decode(Bool.self, forKey: .supportsNotifications)
        priority = try container.decode(Int.self, forKey: .priority)
        cloudUserId = try container.decodeIfPresent(String.self, forKey: .cloudUserId)
    }

    // 🔹 Normalize a URL (removes trailing slashes, trims spaces, redirects openHAB cloud)
    private static func normalizeURL(_ url: String) -> String {
        var cleanedURL = url.trimmingCharacters(in: .whitespacesAndNewlines) // Trim whitespace
        cleanedURL = uriWithoutTrailingSlashes(cleanedURL) // Remove trailing slashes

        return cleanedURL
    }

    /// Removes trailing slashes from a URL string
    private static func uriWithoutTrailingSlashes(_ url: String) -> String {
        var newUrl = url
        while newUrl.hasSuffix("/") {
            newUrl.removeLast()
        }
        return newUrl
    }

    // 🔹 Ensure normalization on encoding (optional, since we store it normalized)
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url) // Already normalized
        try container.encode(username, forKey: .username)
        try container.encode(password, forKey: .password)
        try container.encode(alwaysSendBasicAuth, forKey: .alwaysSendBasicAuth)
        try container.encode(ignoreSSL, forKey: .ignoreSSL)
        try container.encode(supportsNotifications, forKey: .supportsNotifications)
        try container.encode(priority, forKey: .priority)
        if let cloudUserId {
            try container.encode(cloudUserId, forKey: .cloudUserId)
        }
    }

    public static func connectionConfigurationsToString(_ connectionConfigurations: any Collection<ConnectionConfiguration>) -> [String] {
        connectionConfigurations.sorted(by: \.url).map { "url: \($0.url), user: \($0.username)" }
    }
}
