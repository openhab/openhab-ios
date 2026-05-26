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
import WatchConnectivity
import WatchKit

// This class handles values that are passed from the ios app.
@MainActor
final class AppMessageService: NSObject, WCSessionDelegate {
    static let singleton = AppMessageService()

    private nonisolated static let preferencesKey = "watchPreferences"

    // Prevents multiple concurrent sendMessage calls from stalling the WCSession send queue.
    private var contextRequestInFlight = false

    static func updateValuesFromApplicationContext(_ data: Data?) {
        guard let data else {
            Logger.preferences.debug("No watch preferences received in applicationContext yet.")
            return
        }

        do {
            // Decode the connection payload
            let prefs = try JSONDecoder().decode(WatchPreferences.self, from: data)
            Logger.preferences.info("📱 Received WatchPreferences - sitemapForWatch: \(prefs.sitemapForWatch), defaultSitemap: \(prefs.defaultSitemap)")
            AppSettings.shared.localConnectionConfig = prefs.localConnectionConfiguration ?? .localDefault
            AppSettings.shared.remoteConnectionConfig = prefs.remoteConnectionConfiguration ?? .remoteDefault
            AppSettings.shared.sitemapName = prefs.defaultSitemap
            AppSettings.shared.sitemapForWatch = prefs.sitemapForWatch
            AppSettings.shared.sitemapForWatchLabel = prefs.sitemapForWatchLabel
            AppSettings.shared.iconType = IconType(rawValue: prefs.iconType) ?? .svg
            AppSettings.shared.haveReceivedAppContext = true
            if let allHomes = prefs.allHomes {
                let uuidKeyedHomes = Dictionary(uniqueKeysWithValues: allHomes.compactMap { key, value in
                    UUID(uuidString: key).map { ($0, value) }
                })
                let previousHomeIds = Set(AppSettings.shared.storedHomes.keys)
                // Sink in AppSettings.init() persists to both UserDefaults suites.
                AppSettings.shared.storedHomes = uuidKeyedHomes
                if previousHomeIds != Set(uuidKeyedHomes.keys) {
                    Task {
                        await OpenHABItemCache.instance.forceCacheReload()
                    }
                }
            }
            //                   if let trustedCertificates = applicationContext["trustedCertificates"] as? [String: Data] {
            //                       // do we need to do anything here?  We load from the shared keychain.
            //                   }
            Logger.preferences.debug("✅ Applied WatchPreferences - sitemapForWatch now: \(AppSettings.shared.sitemapForWatch)")
        } catch {
            Logger.preferences.error("❌ Failed to decode WatchPreferences: \(error.localizedDescription)")
        }
    }

    private nonisolated func isExpectedApplicationContextRequestFailure(_ error: any Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == WCErrorDomain,
              let code = WCError.Code(rawValue: nsError.code) else { return false }

        switch code {
        case .deviceNotPaired, .companionAppNotInstalled, .notReachable:
            return true
        default:
            return false
        }
    }

    func requestApplicationContext() {
        guard !contextRequestInFlight else {
            Logger.preferences.debug("Context request already in flight, skipping")
            return
        }
        contextRequestInFlight = true
        WCSession.default.sendMessage(["request": "Preferences"]) { [weak self] response in
            let data = response[AppMessageService.preferencesKey] as? Data
            Task { @MainActor [weak self] in
                self?.contextRequestInFlight = false
                AppMessageService.updateValuesFromApplicationContext(data)
            }
        } errorHandler: { [weak self] error in
            Task { @MainActor [weak self] in
                self?.contextRequestInFlight = false
                guard let self, !self.isExpectedApplicationContextRequestFailure(error) else {
                    Logger.preferences.debug("Skipping application context request: \(error.localizedDescription)")
                    return
                }
                Logger.preferences.error("Error sending message \(error.localizedDescription)")
            }
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Logger.preferences.info("activationDidCompleteWith activationState \(activationState.rawValue) error: \(String(describing: error))")
        let data = session.receivedApplicationContext[AppMessageService.preferencesKey] as? Data
        Task { @MainActor [weak self] in
            AppMessageService.updateValuesFromApplicationContext(data)
            // Request fresh preferences now that the session is fully active.
            // This is the only call site for requestApplicationContext(); the App struct
            // init must NOT call it because the session may not be activated yet.
            if activationState == .activated {
                self?.requestApplicationContext()
            }
        }
    }

    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Logger.preferences.info("didReceiveApplicationContext \(applicationContext)")
        let data = applicationContext[AppMessageService.preferencesKey] as? Data
        Task { @MainActor in
            AppMessageService.updateValuesFromApplicationContext(data)
        }
    }

    /** Called on the delegate of the receiver. Will be called on startup if the user info finished transferring when the receiver was not running. */
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Logger.preferences.info("didReceiveUserInfo \(userInfo)")
        let data = userInfo[AppMessageService.preferencesKey] as? Data
        Task { @MainActor in
            AppMessageService.updateValuesFromApplicationContext(data)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let filteredMessages = message.filter { ["remoteUrl", "localUrl", "username"].contains($0.key) }
        Logger.preferences.info("didReceiveMessage some filtered messages: \(filteredMessages)")
        let data = message[AppMessageService.preferencesKey] as? Data
        Task { @MainActor in
            AppMessageService.updateValuesFromApplicationContext(data)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Swift.Void) {
        let filteredMessages = message.filter { ["remoteUrl", "localUrl", "username", "defaultSitemap"].contains($0.key) }
        Logger.preferences.info("didReceiveMessage some filtered messages: \(filteredMessages) with reply handler")
        let data = message[AppMessageService.preferencesKey] as? Data
        Task { @MainActor in
            AppMessageService.updateValuesFromApplicationContext(data)
        }
        // Must always call replyHandler or the sender's WCSession queue stalls permanently.
        replyHandler([:])
    }
}
