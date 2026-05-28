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

import Combine
import Foundation
import OpenHABCore
import os.log
import WatchConnectivity

/// This class receives Watch Request for the configuration data like localUrl.
/// The functionality is activated in the AppDelegate.
class WatchMessageService: NSObject, WCSessionDelegate {
    @MainActor
    static let singleton = WatchMessageService()

    private var cachedWatchPreferences: [String: Data] = [:]
    private let lock = NSLock()

    private var preferencesSubscription: AnyCancellable?

    /// This method gets called when the watch requests the data
    /// ⚠️ This is called off the main thread. Do NOT touch @MainActor stuff.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["request"] != nil else { return }

        let reply = getCachedPreferences()
        replyHandler(reply) // ✅ Used synchronously — no concurrency violation
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Logger.preferences.info("Received message (no reply): \(message, privacy: .public)")
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Logger.preferences.info("WCSession activation completed. State: \(String(describing: activationState)), Error: \(String(describing: error))")
        guard activationState == .activated else { return }
        Task { @MainActor in
            await WatchMessageService.singleton.syncPreferencesToWatch()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        Logger.preferences.info("WCSession became inactive.")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        Logger.preferences.info("WCSession deactivated.")
    }

    // MARK: - Cache Management

    private func getCachedPreferences() -> [String: Data] {
        lock.lock()
        defer { lock.unlock() }
        return cachedWatchPreferences
    }

    private func updateCachedPreferences(_ context: [String: Data]) {
        lock.lock()
        defer { lock.unlock() }
        cachedWatchPreferences = context
    }

    // MARK: - Sync Preferences

    @MainActor
    // swiftlint:disable:next async_without_await
    func subscribeToPreferences() async {
        preferencesSubscription = Preferences.shared.currentHomePreferencesPublisher
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { _ in } receiveValue: { homeSettings in
                Task { @MainActor in
                    await self.syncPreferencesToWatch(homeSettings)
                }
            }
    }

    @MainActor
    // swiftlint:disable:next async_without_await
    func syncPreferencesToWatch(_ homeSettings: HomePreferences? = nil) async {
        guard WCSession.default.activationState == .activated else {
            Logger.preferences.warning("WCSession not activated; skipping sync.")
            return
        }
        let settings = homeSettings ?? Preferences.shared.currentHomePreferences
        let storedHomes = Dictionary(uniqueKeysWithValues: Preferences.shared.storedHomes.map { ($0.key.uuidString, $0.value) })
        // Build per-home credentials from iOS Keychain so Watch can persist them in its own Keychain.
        let homeCredentials = Dictionary(uniqueKeysWithValues: Preferences.shared.storedHomes.keys.map { uuid in
            let local = CredentialsStore.retrieve(homeId: uuid, type: .local)
            let remote = CredentialsStore.retrieve(homeId: uuid, type: .remote)
            return (uuid.uuidString, HomeCredentials(
                localUsername: local?.username ?? "",
                localPassword: local?.password ?? "",
                remoteUsername: remote?.username ?? "",
                remotePassword: remote?.password ?? ""
            ))
        })
        let prefs = WatchPreferences(fromPreferences: settings, allHomes: storedHomes, homeCredentials: homeCredentials)
        let context = prefs.encodedWatchPreferences()

        guard getCachedPreferences() != context else {
            // avoid updating unchanged preferences
            Logger.preferences.debug("⏭️ Preferences unchanged, skipping sync")
            return
        }

        updateCachedPreferences(context)

        do {
            try WCSession.default.updateApplicationContext(context)
            Logger.preferences.debug("📤 Synced WatchPreferences to watch - sitemapForWatch: \(prefs.sitemapForWatch)")
        } catch {
            Logger.preferences.error("Failed to encode or update watch context: \(error.localizedDescription)")
        }
    }
}

@MainActor
extension WatchPreferences {
    init(fromPreferences preferences: HomePreferences, allHomes: [String: HomePreferences]? = nil, homeCredentials: [String: HomeCredentials]? = nil) {
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
            remoteConnectionConfiguration: preferences.remoteConnectionConfig,
            allHomes: allHomes,
            localUsername: preferences.localConnectionConfig.username,
            localPassword: preferences.localConnectionConfig.password,
            activeHomeId: preferences.id,
            homeCredentials: homeCredentials
        )
    }
}
