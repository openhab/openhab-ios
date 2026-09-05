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

/// Pure URL helper functions for the web view, extracted for testability.
enum WebViewURLHelper {
    /// Rewrites `linkURL` to use the active connection's scheme, host, and port if the link's
    /// host+port matches any of the supplied `knownBaseURLStrings`.
    ///
    /// This keeps tile links in-app when the user follows a URL that points to one of the
    /// configured home servers, even if the link uses a different connection endpoint than the
    /// currently active one (e.g. a local-network URL while connected via remote/cloud).
    ///
    /// - Parameters:
    ///   - linkURL: The URL the user tapped.
    ///   - knownBaseURLStrings: All configured connection base URL strings (local + remote for
    ///     every stored home).  Non-parseable strings are silently ignored.
    ///   - activeBaseURLString: The URL string of the currently active connection.  When a match
    ///     is found the link is rewritten to use this origin.
    /// - Returns: The rewritten URL (preserving path, query, and fragment) or `nil` when the
    ///   link does not target a known home server.
    static func rewriteToActiveConnection(
        _ linkURL: URL,
        knownBaseURLStrings: [String],
        activeBaseURLString: String
    ) -> URL? {
        guard let linkHost = linkURL.host, !linkHost.isEmpty else { return nil }
        let linkPort = linkURL.port

        let hostMatches = knownBaseURLStrings.contains { baseString in
            guard let base = URL(string: baseString), let baseHost = base.host else { return false }
            return baseHost == linkHost && base.port == linkPort
        }
        guard hostMatches else { return nil }
        guard let activeBase = URL(string: activeBaseURLString),
              var components = URLComponents(url: linkURL, resolvingAgainstBaseURL: false),
              let activeComponents = URLComponents(url: activeBase, resolvingAgainstBaseURL: false)
        else { return nil }

        components.scheme = activeComponents.scheme
        components.host = activeComponents.host
        components.port = activeComponents.port
        return components.url
    }
    /// Appends a path (and optional query) to a base URL.
    static func appendPath(_ path: String, to baseURL: URL) -> URL? {
        guard var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        if let questionMarkRange = path.range(of: "?") {
            let pathComponent = String(path[..<questionMarkRange.lowerBound])
            let queryComponent = String(path[questionMarkRange.upperBound...])
            urlComponents.path = (urlComponents.path as NSString).appendingPathComponent(pathComponent)
            urlComponents.query = queryComponent
        } else {
            urlComponents.path = (urlComponents.path as NSString).appendingPathComponent(path)
        }
        return urlComponents.url
    }

    /// Normalizes a URL string for comparison.
    /// - Parameters:
    ///   - urlString: The URL string to normalize.
    ///   - includeBasePath: If true, includes the path component; if false, returns only the origin (scheme+host+port).
    /// - Returns: Normalized URL string without trailing slash or fragment.
    static func normalizeForComparison(_ urlString: String?, includeBasePath: Bool = false) -> String? {
        guard let urlString, let url = URL(string: urlString) else { return nil }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil

        if !includeBasePath {
            components?.path = ""
            components?.query = nil
        }

        guard var normalized = components?.url?.absoluteString else { return nil }
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        return normalized
    }

    /// Constructs the full URL for web view loading, applying proxy URL and default path.
    /// - Parameters:
    ///   - baseURL: The base connection URL.
    ///   - proxyURL: Optional cloud proxy URL.
    ///   - path: Optional explicit path to navigate to.
    ///   - defaultPath: The default main UI path from preferences (used when path is nil).
    /// - Returns: The resolved URL to load.
    static func resolveWebViewURL(baseURL: URL?, proxyURL: URL?, path: String?, defaultPath: String) -> URL? {
        guard let baseURLString = baseURL?.absoluteString, var url = URL(string: baseURLString) else {
            return baseURL
        }
        if let proxyURL {
            url = proxyURL
        }
        if let path {
            return appendPath(path, to: url) ?? url
        } else if !defaultPath.isEmpty {
            return appendPath(defaultPath, to: url) ?? url
        }
        return url
    }
}
