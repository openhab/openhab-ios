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
import WatchKit

// This class handles values that are passed from the ios app.
class AppMessageService: NSObject, WCSessionDelegate {
    static let singleton = AppMessageService()

    private let logger = Logger(subsystem: "org.openhab.app.watchkitapp", category: "AppMessageService")

    func updateValuesFromApplicationContext(_ applicationContext: [String: AnyObject]) {
        guard !applicationContext.isEmpty else { return }

        do {
            // Decode the connection payload
            if let connectionPayloadDict = applicationContext["connectionPayload"] as? [String: Any] {
                let data = try JSONSerialization.data(withJSONObject: connectionPayloadDict, options: [])
                let payload = try JSONDecoder().decode(ConnectionPayload.self, from: data)

                ObservableOpenHABDataObject.shared.localConnectionConfig = payload.local
                ObservableOpenHABDataObject.shared.remoteConnectionConfig = payload.remote
            }

            if let sitemapName = applicationContext["defaultSitemap"] as? String {
                ObservableOpenHABDataObject.shared.sitemapName = sitemapName
            }

            if let sitemapForWatch = applicationContext["sitemapForWatch"] as? String {
                ObservableOpenHABDataObject.shared.sitemapForWatch = sitemapForWatch
            }

            if let trustedCertificates = applicationContext["trustedCertificates"] as? [String: Data] {
                // do we need to do anything here?  We load from the shared keychain.
            }

            if let iconType = applicationContext["iconType"] as? IconType {
                ObservableOpenHABDataObject.shared.iconType = iconType
            }

            ObservableOpenHABDataObject.shared.haveReceivedAppContext = true

        } catch {
            logger.error("Failed to decode ConnectionPayload: \(error.localizedDescription)")
        }
    }

    func requestApplicationContext() {
        WCSession.default.sendMessage(
            ["request": "Preferences"],
            replyHandler: { response in
                let filteredMessages = response.filter { ["remoteUrl", "localUrl", "username"].contains($0.key) }
                self.logger.info("Received \(filteredMessages)")

                DispatchQueue.main.async { () in
                    self.updateValuesFromApplicationContext(response as [String: AnyObject])
                }
            }
        ) { error in
            self.logger.error("Error sending message \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        logger.info("activationDidCompleteWith activationState \(activationState.rawValue) error: \(String(describing: error))")
        DispatchQueue.main.async { () in
            self.updateValuesFromApplicationContext(session.receivedApplicationContext as [String: AnyObject])
        }
    }

    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        logger.info("didReceiveApplicationContext \(applicationContext)")
        DispatchQueue.main.async { () in
            self.updateValuesFromApplicationContext(applicationContext as [String: AnyObject])
        }
    }

    /** Called on the delegate of the receiver. Will be called on startup if the user info finished transferring when the receiver was not running. */
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        logger.info("didReceiveUserInfo \(userInfo)")
        DispatchQueue.main.async { () in
            self.updateValuesFromApplicationContext(userInfo as [String: AnyObject])
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let filteredMessages = message.filter { ["remoteUrl", "localUrl", "username"].contains($0.key) }
        logger.info("didReceiveMessage some filtered messages: \(filteredMessages)")
        DispatchQueue.main.async { () in
            self.updateValuesFromApplicationContext(message as [String: AnyObject])
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Swift.Void) {
        let filteredMessages = message.filter { ["remoteUrl", "localUrl", "username", "defaultSitemap"].contains($0.key) }
        logger.info("didReceiveMessage some filtered messages: \(filteredMessages) with reply handler")

        DispatchQueue.main.async { () in
            self.updateValuesFromApplicationContext(message as [String: AnyObject])
        }
    }
}
