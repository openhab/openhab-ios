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

/// Persistent storage for HTTP ETags used for change detection in our Webviews which our MainUI uses extensively for asset caching
public actor ETagCache {
    public static let shared = ETagCache()

    private var etags: [String: String] = [:]
    private let persistencePath: URL?

    public init() {
        // Calculate the default persistence path
        let path: URL
        // Maybe this could be used for the watch? We will keep it compatible just in case.
        #if os(watchOS)
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        path = URL(fileURLWithPath: documentsDirectory).appendingPathComponent("etagCache")
        #else
        // Try app group container first, fall back to documents directory for testing
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.openhab.app") {
            path = appGroupURL.appendingPathComponent("etagCache")
        } else {
            // Fallback for test environment where app group may not be available
            let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            path = URL(fileURLWithPath: documentsDirectory).appendingPathComponent("etagCache")
        }
        #endif

        persistencePath = path
        let loadedETags = Self.loadETags(from: path)
        etags = loadedETags
        Logger.etagCache.info("ETagCache initialized with \(loadedETags.count) cached ETags")
    }

    /// Creates an ETagCache for testing with an optional custom persistence path.
    /// Pass `nil` for in-memory only operation (no file I/O).
    public init(persistencePath: URL?) {
        self.persistencePath = persistencePath
        if let path = persistencePath {
            etags = Self.loadETags(from: path)
        } else {
            etags = [:]
        }
    }

    // MARK: - Type Methods

    private static func loadETags(from path: URL) -> [String: String] {
        guard FileManager.default.fileExists(atPath: path.path) else {
            Logger.etagCache.debug("No existing ETag cache file found")
            return [:]
        }

        do {
            let data = try Data(contentsOf: path)
            let decoded = try PropertyListDecoder().decode([String: String].self, from: data)
            Logger.etagCache.info("Loaded \(decoded.count) ETags from disk")
            return decoded
        } catch {
            Logger.etagCache.error("Failed to load ETags: \(error.localizedDescription)")
            return [:]
        }
    }

    // MARK: - Instance Methods

    /// Retrieves the cached ETag for a given URL
    public func getETag(for url: String) -> String? {
        etags[url]
    }

    /// Stores an ETag for a given URL and persists to disk
    public func storeETag(_ etag: String, for url: String) async {
        etags[url] = etag
        await saveETags()
        Logger.etagCache.debug("Stored ETag for \(url): \(etag)")
    }

    /// Removes the cached ETag for a given URL
    public func clearETag(for url: String) async {
        etags.removeValue(forKey: url)
        await saveETags()
        Logger.etagCache.debug("Cleared ETag for \(url)")
    }

    /// Clears all cached ETags
    public func clearAll() async {
        etags.removeAll()
        await saveETags()
        Logger.etagCache.info("Cleared all cached ETags")
    }

    // MARK: - Persistence

    // swiftlint:disable:next async_without_await
    private func saveETags() async {
        guard let path = persistencePath else {
            Logger.etagCache.debug("No persistence path, skipping save")
            return
        }

        do {
            let etagsToSave = etags
            let data = try PropertyListEncoder().encode(etagsToSave)
            try data.write(to: path, options: [.atomic])
            Logger.etagCache.debug("Saved \(etagsToSave.count) ETags to disk")
        } catch {
            Logger.etagCache.error("Failed to save ETags: \(error.localizedDescription)")
        }
    }
}
