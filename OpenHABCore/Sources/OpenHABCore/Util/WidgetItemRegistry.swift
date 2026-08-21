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

/// Manages tracking of which openHAB items have active widgets.
/// Uses shared UserDefaults to communicate between the app and widget extension.
public actor WidgetItemRegistry {
    public static let shared = WidgetItemRegistry()

    private let defaults: UserDefaults?
    private let itemsKey = "widgetTrackedItems"
    private let timestampsKey = "widgetTrackedItemTimestamps"

    private init() {
        defaults = UserDefaults(suiteName: "group.org.openhab.app")
    }

    /// Register an item as being displayed in a widget
    /// - Parameters:
    ///   - itemName: The name of the openHAB item
    ///   - homeId: The UUID of the home containing this item
    public func registerItem(name itemName: String, homeId: UUID) {
        guard let defaults else {
            Logger.widgets.error("Failed to access shared UserDefaults")
            return
        }

        var items = getRegisteredItems()
        let key = "\(homeId.uuidString):\(itemName)"
        items.insert(key)

        // Update timestamp for this item
        var timestamps = getTimestamps()
        timestamps[key] = Date()

        defaults.set(Array(items), forKey: itemsKey)
        setTimestamps(timestamps)
        Logger.widgets.info("Registered widget item: \(itemName) for home \(homeId)")
    }

    /// Unregister an item (when widget is removed)
    /// - Parameters:
    ///   - itemName: The name of the openHAB item
    ///   - homeId: The UUID of the home containing this item
    public func unregisterItem(name itemName: String, homeId: UUID) {
        guard let defaults else {
            Logger.widgets.error("Failed to access shared UserDefaults")
            return
        }

        var items = getRegisteredItems()
        let key = "\(homeId.uuidString):\(itemName)"
        items.remove(key)

        // Remove timestamp for this item
        var timestamps = getTimestamps()
        timestamps.removeValue(forKey: key)

        defaults.set(Array(items), forKey: itemsKey)
        setTimestamps(timestamps)
        Logger.widgets.info("Unregistered widget item: \(itemName) for home \(homeId)")
    }

    /// Get all registered items grouped by home
    /// - Returns: Dictionary mapping home UUIDs to arrays of item names
    public func getItemsByHome() -> [UUID: [String]] {
        let items = getRegisteredItems()
        var result: [UUID: [String]] = [:]

        for item in items {
            let components = item.split(separator: ":", maxSplits: 1)
            guard components.count == 2,
                  let homeId = UUID(uuidString: String(components[0])) else {
                continue
            }

            let itemName = String(components[1])
            result[homeId, default: []].append(itemName)
        }

        return result
    }

    /// Get all registered item names (without home grouping)
    /// - Returns: Array of all item names that have widgets
    public func getAllItemNames() -> [String] {
        let itemsByHome = getItemsByHome()
        return Array(Set(itemsByHome.values.flatMap(\.self)))
    }

    /// Clear all registered items (useful for testing or cleanup)
    public func clearAll() {
        defaults?.removeObject(forKey: itemsKey)
        defaults?.removeObject(forKey: timestampsKey)
        Logger.widgets.info("Cleared all registered widget items")
    }

    /// Remove items that haven't been updated recently (stale widgets)
    /// - Parameter olderThan: Time interval in seconds (default: 1 hour)
    /// - Returns: Number of items removed
    @discardableResult
    public func removeStaleItems(olderThan interval: TimeInterval = 3600) -> Int {
        guard let defaults else { return 0 }

        let cutoffDate = Date().addingTimeInterval(-interval)
        var items = getRegisteredItems()
        var timestamps = getTimestamps()

        var removedCount = 0
        var timestampsUpdated = false

        for itemKey in Array(items) {
            // If no timestamp exists or timestamp is too old, remove it
            if let timestamp = timestamps[itemKey], timestamp < cutoffDate {
                items.remove(itemKey)
                timestamps.removeValue(forKey: itemKey)
                removedCount += 1
                Logger.widgets.debug("Removed stale widget item: \(itemKey)")
            } else if timestamps[itemKey] == nil {
                // Item has no timestamp, probably from old version - keep it but add timestamp
                timestamps[itemKey] = Date()
                timestampsUpdated = true
            }
        }

        if removedCount > 0 || timestampsUpdated {
            defaults.set(Array(items), forKey: itemsKey)
            setTimestamps(timestamps)
            Logger.widgets.info("Removed \(removedCount) stale widget items")
        }

        return removedCount
    }

    private func getRegisteredItems() -> Set<String> {
        guard let defaults else { return [] }
        let items = defaults.stringArray(forKey: itemsKey) ?? []
        return Set(items)
    }

    private func getTimestamps() -> [String: Date] {
        guard let defaults else { return [:] }
        guard let data = defaults.data(forKey: timestampsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Date].self, from: data)) ?? [:]
    }

    private func setTimestamps(_ timestamps: [String: Date]) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(timestamps) {
            defaults.set(data, forKey: timestampsKey)
        }
    }
}
