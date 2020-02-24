// Copyright (c) 2010-2020 Contributors to the openHAB project
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
import OpenHABCoreWatch
import os.log
import WatchConnectivity
import WatchKit

// This class handles values that are passed from the ios app.
class AppMessageService: NSObject, WCSessionDelegate {
    static let singleton = AppMessageService()

    func updateValuesFromApplicationContext(_ applicationContext: [String: AnyObject]) {
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

            if let username = applicationContext["username"] as? String {
                ObservableOpenHABDataObject.shared.openHABUsername = username
            }

            if let password = applicationContext["password"] as? String {
                ObservableOpenHABDataObject.shared.openHABPassword = password
            }

            if let ignoreSSL = applicationContext["ignoreSSL"] as? Bool {
                ObservableOpenHABDataObject.shared.ignoreSSL = ignoreSSL
            }

            if let trustedCertificate = applicationContext["trustedCertificates"] as? [String: Any] {
                let serverCertificateManager = ServerCertificateManager(ignoreSSL: ObservableOpenHABDataObject.shared.ignoreSSL)
                serverCertificateManager.trustedCertificates = trustedCertificate
                serverCertificateManager.saveTrustedCertificates()
                NetworkConnection.shared.serverCertificateManager = serverCertificateManager
            }

            if let alwaysSendCreds = applicationContext["alwaysSendCreds"] as? Bool {
                ObservableOpenHABDataObject.shared.openHABAlwaysSendCreds = alwaysSendCreds
            }

            ObservableOpenHABDataObject.shared.haveReceivedAppContext = true
        }
    }

    func requestApplicationContext() {
        WCSession
            .default
            .sendMessage(["request": "Preferences"],
                         replyHandler: { (response) in
                             let filteredMessages = response.filter { ["remoteUrl", "localUrl", "username"].contains($0.key) }
                             os_log("Received %{PUBLIC}@", log: .watch, type: .info, "\(filteredMessages)")

                             DispatchQueue.main.async { () -> Void in
                                 AppMessageService.singleton.updateValuesFromApplicationContext(response as [String: AnyObject])
                             }
                         },
                         errorHandler: { (error) in
                             os_log("Error sending message %{PUBLIC}@", log: .watch, type: .info, "\(error)")

            })
    }

    @available(watchOSApplicationExtension 2.2, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        os_log("activationDidCompleteWith activationState %{PUBLIC}@ error: %{PUBLIC}@", log: .watch, type: .info, "\(activationState)", "\(String(describing: error))")
        DispatchQueue.main.async { () -> Void in
            self.updateValuesFromApplicationContext(session.receivedApplicationContext as [String: AnyObject])
        }
    }

    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        os_log("didReceiveApplicationContext %{PUBLIC}@", log: .watch, type: .info, "\(applicationContext)")
        DispatchQueue.main.async { () -> Void in
            self.updateValuesFromApplicationContext(applicationContext as [String: AnyObject])
        }
    }

    /** Called on the delegate of the receiver. Will be called on startup if the user info finished transferring when the receiver was not running. */
    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        os_log("didReceiveUserInfo %{PUBLIC}@", log: .watch, type: .info, "\(userInfo)")
        DispatchQueue.main.async { () -> Void in
            self.updateValuesFromApplicationContext(userInfo as [String: AnyObject])
        }
    }

    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let filteredMessages = message.filter { ["remoteUrl", "localUrl", "username"].contains($0.key) }
        os_log("didReceiveMessage some filtered messages: %{PUBLIC}@", log: .watch, type: .info, "\(filteredMessages)")
        DispatchQueue.main.async { () -> Void in
            self.updateValuesFromApplicationContext(message as [String: AnyObject])
        }
    }

    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Swift.Void) {
        let filteredMessages = message.filter { ["remoteUrl", "localUrl", "username", "defaultSitemap"].contains($0.key) }
        os_log("didReceiveMessage some filtered messages: %{PUBLIC}@ with reply handler", log: .watch, type: .info, "\(filteredMessages)")

        DispatchQueue.main.async { () -> Void in
            self.updateValuesFromApplicationContext(message as [String: AnyObject])
        }
    }
}
