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
import OpenHABCore
import os.log
import WatchConnectivity

// This class receives Watch Request for the configuration data like localUrl.
// The functionality is activated in the AppDelegate.
class WatchMessageService: NSObject, WCSessionDelegate {
    static let singleton = WatchMessageService()

    private lazy var logger = Logger(subsystem: "org.openhab.app", category: "WatchMessageService")

    // This method gets called when the watch requests the data
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("Received message with reply handler: \(message, privacy: .public)")

        guard message["request"] != nil else {
            logger.warning("Invalid message: no 'request' key.")
            return
        }

        Task { @MainActor in
            let prefs = WatchPreferences(fromPreferences: Preferences.self)
            replyHandler(prefs.encodedWatchPreferences())
            logger.debug("Sent WatchPreferences in replyHandler.")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        logger.info("Received message (no reply): \(message, privacy: .public)")
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        logger.info("WCSession activation completed. State: \(String(describing: activationState)), Error: \(String(describing: error))")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("WCSession became inactive.")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("WCSession deactivated.")
    }

    // MARK: - Sync Preferences

    @MainActor
    public func syncPreferencesToWatch() {
        guard WCSession.default.activationState == .activated else {
            logger.warning("WCSession not activated; skipping sync.")
            return
        }

        let prefs = WatchPreferences(fromPreferences: Preferences.self)
        let context = prefs.encodedWatchPreferences()

        do {
            try WCSession.default.updateApplicationContext(context)
            logger.debug("Successfully updated application context with WatchPreferences.")
        } catch {
            logger.error("Failed to encode or update watch context: \(error.localizedDescription)")
        }
    }
}

@MainActor
public extension WatchPreferences {
    init(fromPreferences preferences: Preferences.Type) {
        self.init(
            localUrl: preferences.localUrl,
            remoteUrl: preferences.remoteUrl,
            username: preferences.username,
            password: preferences.password,
            alwaysSendCreds: preferences.alwaysSendCreds,
            defaultSitemap: preferences.defaultSitemap,
            ignoreSSL: preferences.ignoreSSL,
            sitemapForWatch: preferences.sitemapForWatch,
            sitemapForWatchLabel: preferences.sitemapForWatchLabel,
            iconType: preferences.iconType,
            demoMode: preferences.demomode,
            localConnectionConfiguration: preferences.localConnectionConfig,
            remoteConnectionConfiguration: preferences.remoteConnectionConfig
        )
    }
}
