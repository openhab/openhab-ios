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

/// Result of an ETag check operation
public enum ETagCheckResult: Sendable {
    case unchanged // Content hasn't changed, skip reloading and depend on the webview's cache
    case changed // Content has changed, reload
    case failed(any Error) // Check failed, reload
}

/// Service for checking if remote content has changed using HTTP ETags
public actor ETagChecker {
    private let httpClient: HTTPClient
    private let cache: ETagCache

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
        cache = ETagCache.shared
    }

    /// Internal initializer for testing - allows cache injection
    init(httpClient: HTTPClient, cache: ETagCache) {
        self.httpClient = httpClient
        self.cache = cache
    }

    /// Checks if content at the given URL has changed since last check
    /// - Parameter url: The URL to check
    /// - Returns: ETagCheckResult indicating whether content changed
    public func checkIfChanged(url: URL) async -> ETagCheckResult {
        let urlString = url.absoluteString

        // Get cached ETag
        let cachedETag = await cache.getETag(for: urlString)

        do {
            // Perform HEAD request with 5 second timeout, worst case we reload, but lets not delay stuff
            let (_, response): (Data, URLResponse) = try await httpClient.doRequest(
                baseURL: url,
                timeout: 5.0,
                method: "HEAD",
                type: .data
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.etagChecker.warning("Response is not HTTPURLResponse")
                return .changed
            }

            var newETag: String?
            for (key, value) in httpResponse.allHeaderFields {
                if let keyString = key as? String, keyString.lowercased() == "etag", let valueString = value as? String {
                    newETag = valueString
                    break
                }
            }

            guard let newETag else {
                Logger.etagChecker.debug("No ETag header in response for \(urlString)")
                return .changed // Server doesn't support ETags, always reload
            }

            let normalizedNewETag = normalizeETag(newETag)
            Logger.etagChecker.debug("Received ETag for \(urlString): \(normalizedNewETag)")

            // First time checking this URL - store and reload
            guard let cachedETag else {
                Logger.etagChecker.info("First time checking \(urlString), storing ETag and reloading")
                await cache.storeETag(normalizedNewETag, for: urlString)
                return .changed
            }

            let normalizedCachedETag = normalizeETag(cachedETag)

            if normalizedNewETag == normalizedCachedETag {
                Logger.etagChecker.info("ETag unchanged for \(urlString)")
                return .unchanged
            }
            Logger.etagChecker.info("ETag changed for \(urlString): \(normalizedCachedETag) -> \(normalizedNewETag)")
            await cache.storeETag(normalizedNewETag, for: urlString)
            return .changed

        } catch {
            Logger.etagChecker.warning("ETag check failed for \(urlString): \(error.localizedDescription)")
            return .failed(error)
        }
    }

    /// Normalizes an ETag by removing surrounding quotes
    /// - Parameter etag: The raw ETag from HTTP header
    /// - Returns: Normalized ETag without quotes
    private func normalizeETag(_ etag: String) -> String {
        etag.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}
