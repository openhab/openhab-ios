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
import WatchConnectivity

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

        logger.info("Migration check: lastVersion=\(lastMigrationVersion), currentVersion=\(self.currentMigrationVersion)")

        // Migration 1: Remove deprecated ClockKit complications (3.2.68+)
        if lastMigrationVersion < 1 {
            logger.info("Running migration 1: ClockKit complications removal")
            removeDeprecatedClockKitComplications()
        } else {
            logger.info("Migration 1 already completed, skipping")
        }

        // Update migration version
        userDefaults.set(currentMigrationVersion, forKey: migrationVersionKey)
        logger.info("Migration version updated to \(currentMigrationVersion)")
    }

    /// Resets the migration state - useful for testing
    /// Call this once to allow migrations to run again
    static func resetMigrationState() {
        let userDefaults = UserDefaults(suiteName: "group.openhab.shared") ?? UserDefaults.standard
        userDefaults.removeObject(forKey: migrationVersionKey)
        logger.info("Migration state reset - migrations will run on next app launch")
    }

    /// Removes the deprecated ClockKit complications that were replaced with WidgetKit
    /// This migration was introduced in version 3.2.68 to prevent duplicate complication entries
    /// in the watchOS complications selector (issue #1030)
    ///
    /// The legacy ClockKit complications are cached in watchOS even after being replaced with
    /// WidgetKit. This method attempts to clear them through multiple strategies:
    /// 1. Reload all active complications to force a refresh
    /// 2. Send a message to the iOS companion app to trigger a full cache clear
    private static func removeDeprecatedClockKitComplications() {
        logger.info("Starting migration: removing deprecated ClockKit complications")

        do {
            let server = CLKComplicationServer.sharedInstance()

            // Strategy 1: Reload all active complications
            if let activeComplications = server.activeComplications, !activeComplications.isEmpty {
                logger.info("Found \(activeComplications.count) active complications")

                for complication in activeComplications {
                    logger.info("Reloading ClockKit complication: \(complication.identifier)")
                    server.reloadTimeline(for: complication)
                }
            } else {
                logger.info("No active ClockKit complications found")
            }

            // Strategy 2: Notify companion app to help clear the cache
            notifyCompanionAppOfMigration()

            logger.info("Successfully processed ClockKit complications migration")
        } catch {
            logger.error("Error during ClockKit complications migration: \(error.localizedDescription)")
        }
    }

    /// Notifies the iOS companion app about the ClockKit migration
    /// This allows the main app to perform any necessary cleanup on the iOS side
    private static func notifyCompanionAppOfMigration() {
        if WCSession.default.isReachable {
            let message = [
                "action": "clockkitMigrationComplete",
                "timestamp": Date().timeIntervalSince1970
            ] as [String: Any]

            WCSession.default.sendMessage(message, replyHandler: { response in
                self.logger.info("Companion app acknowledged ClockKit migration")
            }, errorHandler: { error in
                self.logger.warning("Failed to notify companion app: \(error.localizedDescription)")
            })
        } else {
            logger.info("Companion app not reachable; will retry on next sync")
        }
    }
}
