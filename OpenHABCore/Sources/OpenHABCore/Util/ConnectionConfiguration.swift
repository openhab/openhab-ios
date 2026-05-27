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

    // 🔹 Ensure normalization on decoding. decodeIfPresent is used for every field
    // that has a default so that stored data from older versions (missing those fields)
    // decodes without throwing.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawURL = try container.decode(String.self, forKey: .url)
        url = ConnectionConfiguration.normalizeURL(rawURL)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        alwaysSendBasicAuth = try container.decodeIfPresent(Bool.self, forKey: .alwaysSendBasicAuth) ?? false
        ignoreSSL = try container.decodeIfPresent(Bool.self, forKey: .ignoreSSL) ?? false
        supportsNotifications = try container.decodeIfPresent(Bool.self, forKey: .supportsNotifications) ?? false
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 10
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
}

extension ConnectionConfiguration {
    /// Decodes a `ConnectionConfiguration` from a keyed container with a role-specific default
    /// for `supportsNotifications`. Use this instead of `decodeIfPresent(_:forKey:)` when the
    /// caller knows whether the config is local (false) or remote (true), so that old stored data
    /// written before the field existed doesn't silently disable cloud/push paths.
    static func decode<K: CodingKey>(from container: KeyedDecodingContainer<K>,
                                     forKey key: K,
                                     defaultNotifications: Bool) throws -> ConnectionConfiguration? {
        guard container.contains(key) else { return nil }
        let nested = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: key)
        var config = try ConnectionConfiguration(
            url: nested.decode(String.self, forKey: .url),
            username: nested.decodeIfPresent(String.self, forKey: .username) ?? "",
            password: nested.decodeIfPresent(String.self, forKey: .password) ?? "",
            alwaysSendBasicAuth: nested.decodeIfPresent(Bool.self, forKey: .alwaysSendBasicAuth) ?? false,
            ignoreSSL: nested.decodeIfPresent(Bool.self, forKey: .ignoreSSL) ?? false,
            supportsNotifications: nested.decodeIfPresent(Bool.self, forKey: .supportsNotifications) ?? defaultNotifications,
            priority: nested.decodeIfPresent(Int.self, forKey: .priority) ?? 10
        )
        config.cloudUserId = try nested.decodeIfPresent(String.self, forKey: .cloudUserId)
        return config
    }
}

public extension ConnectionConfiguration {
    /// The host component of the connection URL, if parseable.
    var host: String? { URL(string: url)?.host }

    /// URL suitable for diagnostics; credentials embedded in the URL are stripped.
    var publicLogURL: String {
        guard var components = URLComponents(string: url) else {
            return url
        }
        components.user = nil
        components.password = nil
        return components.string ?? url
    }

    /// Connection details safe to expose in diagnostics.
    var publicLogDescription: String {
        "url: \(publicLogURL), priority: \(priority), cloud: \(isCloudConnection), usernameConfigured: \(!username.isEmpty)"
    }

    /// Whether this connection is to an openHAB Cloud instance.
    /// Currently determined by the "openHAB Cloud Service" user preference (`supportsNotifications`).
    var isCloudConnection: Bool { supportsNotifications }
}

extension ConnectionConfiguration: CustomStringConvertible {
    public var description: String {
        "url: \(url), user: \(username)"
    }
}
