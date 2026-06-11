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

import ClockKit
import Foundation
import os.log

/// Handles app migrations between versions
final class MigrationManager {
    private static let migrationVersionKey = "MigrationVersion"
    private static let logger = Logger(subsystem: "org.openhab.app.watch", category: "MigrationManager")

    /// Current app version for migrations
    private static let currentMigrationVersion = 1

    /// Performs all necessary migrations on app launch
    static func performMigrations() {
        let userDefaults = UserDefaults(suiteName: "group.openhab.shared") ?? UserDefaults.standard
        let lastMigrationVersion = userDefaults.integer(forKey: migrationVersionKey)

        // Migration 1: Remove deprecated ClockKit complications (3.2.68+)
        if lastMigrationVersion < 1 {
            removeDeprecatedClockKitComplications()
        }

        // Update migration version
        userDefaults.set(currentMigrationVersion, forKey: migrationVersionKey)
    }

    /// Removes the deprecated ClockKit complications that were replaced with WidgetKit
    /// This migration was introduced in version 3.2.68 to prevent duplicate complication entries
    /// in the watchOS complications selector (issue #1030)
    private static func removeDeprecatedClockKitComplications() {
        logger.info("Starting migration: removing deprecated ClockKit complications")

        do {
            let server = CLKComplicationServer.sharedInstance()

            // Get all active complications
            let activeComplications = server.activeComplications

            guard !activeComplications.isEmpty else {
                logger.info("No active ClockKit complications found")
                return
            }

            logger.info("Found \(activeComplications.count) active complications")

            // Remove all ClockKit complications by reloading their timeline
            for complication in activeComplications {
                logger.info("Removing ClockKit complication: \(complication.identifier)")
                server.reloadTimeline(for: complication)
            }

            logger.info("Successfully removed deprecated ClockKit complications")
        } catch {
            logger.error("Failed to remove ClockKit complications: \(error.localizedDescription)")
        }
    }
}
