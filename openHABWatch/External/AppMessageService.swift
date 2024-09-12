// Copyright (c) 2010-2024 Contributors to the openHAB project
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
    
    private let logger = Logger(subsystem: "org.openhab.app.watch", category: "AppMessageService")

    func updateValuesFromApplicationContext(_ applicationContext: [String: AnyObject]) {
        if NetworkConnection.shared == nil {
            NetworkConnection.initialize(ignoreSSL: Preferences.ignoreSSL, interceptor: nil)
        }
        if !applicationContext.isEmpty {
            if let localUrl = applicationContext["localUrl"] as? String {
                ObservableOpenHABDataObject.shared.localUrl = localUrl
            }

            if let remoteUrl = applicationContext["remoteUrl"] as? String {
                ObservableOpenHABDataObject.shared.remoteUrl = remoteUrl
            }
            // !!!
            if let sitemapName = applicationContext["defaultSitemap"] as? String {
                ObservableOpenHABDataObject.shared.sitemapName = sitemapName
            }

            if let sitemapForWatch = applicationContext["sitemapForWatch"] as? String {
                ObservableOpenHABDataObject.shared.sitemapForWatch = sitemapForWatch
            }

            if let username = applicationContext["username"] as? String {
                ObservableOpenHABDataObject.shared.openHABUsername = username
            }

            if let password = applicationContext["password"] as? String {
                ObservableOpenHABDataObject.shared.openHABPassword = password
            }

            if let ignoreSSL = applicationContext["ignoreSSL"] as? Bool {
                ObservableOpenHABDataObject.shared.ignoreSSL = ignoreSSL
            }

            if let trustedCertificates = applicationContext["trustedCertificates"] as? [String: Data] {
                NetworkConnection.shared.serverCertificateManager.trustedCertificates = trustedCertificates
                NetworkConnection.shared.serverCertificateManager.saveTrustedCertificates()
            }

            if let alwaysSendCreds = applicationContext["alwaysSendCreds"] as? Bool {
                ObservableOpenHABDataObject.shared.openHABAlwaysSendCreds = alwaysSendCreds
            }

            if let iconType = applicationContext["iconType"] as? IconType {
                ObservableOpenHABDataObject.shared.iconType = iconType
            }

            ObservableOpenHABDataObject.shared.haveReceivedAppContext = true
        }
    }

    func requestApplicationContext() {
        WCSession
            .default
            .sendMessage(
                ["request": "Preferences"],
                replyHandler: { (response) in
                    let filteredMessages = response.filter { ["remoteUrl", "localUrl", "username"].contains($0.key) }
                    self.logger.info("Received \(filteredMessages)")

                    DispatchQueue.main.async { () in
                        self.updateValuesFromApplicationContext(response as [String: AnyObject])
                    }
                },
                errorHandler: { (error) in
                    self.logger.error("Error sending message \(error.localizedDescription)")
                }
            )
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        logger.info("activationDidCompleteWith activationState \(activationState.rawValue) error: \(String(describing: error))")
        DispatchQueue.main.async { () in
            self.updateValuesFromApplicationContext(session.receivedApplicationContext as [String: AnyObject])
        }
    }

    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        logger.info("didReceiveApplicationContext \(applicationContext)" )
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
