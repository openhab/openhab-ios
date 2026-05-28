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
import OpenHABCore
import os.log
import WidgetKit

/// Monitors openHAB items that have active widgets and reloads widgets when items change
@MainActor
class WidgetItemMonitor {
    static let shared = WidgetItemMonitor()

    private var monitoringTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?
    private var isMonitoring = false

    private init() {}

    /// Start monitoring items that have widgets
    func startMonitoring() {
        guard !isMonitoring else {
            return
        }

        isMonitoring = true
        Logger.widgets.info("Starting widget item monitoring")

        // Start network monitoring for SSE connection
        monitoringTask = Task {
            await ItemEventStream.startMonitoringNetwork()
        }

        // Start listening to item state changes
        // Run on background thread to avoid MainActor blocking
        streamTask = Task.detached { [weak self] in
            guard let self else { return }

            // Update tracked items initially
            await updateTrackedItems()

            // Listen for state change events
            for await message in await ItemEventStream.shared.stream() {
                await handle(message)
            }
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }

        Logger.widgets.info("Stopping widget item monitoring")
        isMonitoring = false

        monitoringTask?.cancel()
        streamTask?.cancel()
        monitoringTask = nil
        streamTask = nil
    }

    /// Manually refresh the list of tracked items (call when widgets are added/removed)
    func refreshTrackedItems() async {
        await updateTrackedItems()
    }

    /// Clean up stale widget items that haven't been refreshed recently
    /// Widgets refresh every 5 minutes, so items not updated in 1+ hours are likely deleted
    func cleanupStaleItems() async {
        let removedCount = await WidgetItemRegistry.shared.removeStaleItems(olderThan: 3600) // 1 hour

        if removedCount > 0 {
            Logger.widgets.info("Cleaned up \(removedCount) stale widget items")
            await updateTrackedItems()
        }
    }

    private func updateTrackedItems() async {
        let itemNames = await WidgetItemRegistry.shared.getAllItemNames()

        guard !itemNames.isEmpty else {
            await ItemEventStream.trackItems([])
            return
        }

        Logger.widgets.info("Tracking \(itemNames.count) widget items: \(itemNames.joined(separator: ", "))")
        await ItemEventStream.trackItems(itemNames)
    }

    private func handle(_ message: StreamOutput<StateStreamMessage>) async {
        switch message {
        case .connected:
            await updateTrackedItems()

        case let .event(event):
            switch event {
            case let .state(item, state):
                Logger.widgets.info("Item '\(item)' changed to '\(state)' - reloading widgets")
                reloadWidgets(for: item)

            case .ready:
                await updateTrackedItems()

            case .alive:
                break

            case let .unknown(raw):
                Logger.widgets.warning("Unknown SSE message: \(raw)")
            }

        case let .disconnected(error):
            if let error {
                Logger.widgets.warning("SSE disconnected: \(error.localizedDescription)")
            }
        }
    }

    private func reloadWidgets(for itemName: String) {
        // Reload all switch and sensor widgets
        // Note: This reloads all widgets of these types, not just the specific item
        WidgetCenter.shared.reloadTimelines(ofKind: "OpenHABSwitchWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "OpenHABSensorWidget")
    }
}
