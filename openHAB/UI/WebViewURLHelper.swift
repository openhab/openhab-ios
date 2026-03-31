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
