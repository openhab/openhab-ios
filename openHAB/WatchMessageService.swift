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

import Combine
import Foundation
import OpenHABCore
import os.log
import WatchConnectivity

// This class receives Watch Request for the configuration data like localUrl.
// The functionality is activated in the AppDelegate.
class WatchMessageService: NSObject, WCSessionDelegate {
    @MainActor
    static let singleton = WatchMessageService()

    private lazy var logger = Logger(subsystem: "org.openhab.app", category: "WatchMessageService")

    private var cachedWatchPreferences: [String: Data] = [:]
    private let lock = NSLock()

    private var preferencesSubscription: AnyCancellable?

    // This method gets called when the watch requests the data
    // ⚠️ This is called off the main thread. Do NOT touch @MainActor stuff.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["request"] != nil else { return }

        lock.lock()
        let reply = cachedWatchPreferences
        lock.unlock()

        replyHandler(reply) // ✅ Used synchronously — no concurrency violation
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
    public func subscribeToPreferences() {
        let currentlyUsedSettings: AnyPublisher<any Sendable, Never> = Preferences.$currentlyUsedSettings
            .map { $0 as any Sendable }
            .eraseToAnyPublisher()
        let watchRelatedSettings: AnyPublisher<any Sendable, Never> = currentlyUsedSettings
            .merge(
                with:
                Preferences.$defaultSitemap.map { $0 as any Sendable }.eraseToAnyPublisher(),
                Preferences.$sitemapForWatch.map { $0 as any Sendable }.eraseToAnyPublisher(),
                Preferences.$sitemapForWatchLabel.map { $0 as any Sendable }.eraseToAnyPublisher(),
                Preferences.$iconType.map { $0 as any Sendable }.eraseToAnyPublisher(),
                Preferences.$demomode.map { $0 as any Sendable }.eraseToAnyPublisher(),
                Preferences.$localConnectionConfig.map { $0 as any Sendable }.eraseToAnyPublisher(),
                Preferences.$localConnectionConfig.map { $0 as any Sendable }.eraseToAnyPublisher()
            )
            .eraseToAnyPublisher()

        preferencesSubscription = watchRelatedSettings
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { _ in } receiveValue: { _ in
                self.syncPreferencesToWatch()
            }
    }

    @MainActor
    public func syncPreferencesToWatch() {
        guard WCSession.default.activationState == .activated else {
            logger.warning("WCSession not activated; skipping sync.")
            return
        }

        let prefs = WatchPreferences(fromPreferences: Preferences.self)
        let context = prefs.encodedWatchPreferences()

        guard cachedWatchPreferences != context else {
            // avoid update of update unchanged preferences
            return
        }

        lock.lock()
        cachedWatchPreferences = context
        lock.unlock()

        do {
            try WCSession.default.updateApplicationContext(context)
            logger.debug("Successfully updated application context with WatchPreferences.")
        } catch {
            logger.error("Failed to encode or update watch context: \(error.localizedDescription)")
        }
    }
}

@MainActor
extension WatchPreferences {
    init(fromPreferences preferences: Preferences.Type) {
        self.init(
            localUrl: preferences.localConnectionConfig.url,
            remoteUrl: preferences.remoteConnectionConfig.url,
            username: preferences.remoteConnectionConfig.username,
            password: preferences.remoteConnectionConfig.password,
            alwaysSendCreds: preferences.remoteConnectionConfig.alwaysSendBasicAuth,
            defaultSitemap: preferences.defaultSitemap,
            ignoreSSL: preferences.remoteConnectionConfig.ignoreSSL,
            sitemapForWatch: preferences.sitemapForWatch,
            sitemapForWatchLabel: preferences.sitemapForWatchLabel,
            iconType: preferences.iconType,
            demoMode: preferences.demomode,
            localConnectionConfiguration: preferences.localConnectionConfig,
            remoteConnectionConfiguration: preferences.remoteConnectionConfig
        )
    }
}
