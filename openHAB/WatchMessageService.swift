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

// This class receives Watch Request for the configuration data like localUrl.
// The functionality is activated in the AppDelegate.
class WatchMessageService: NSObject, WCSessionDelegate {
    static let singleton = WatchMessageService()

    // This method gets called when the watch requests the data
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // TODO: Use RemoteUrl, TOO
        os_log("didReceiveMessage %{PUBLIC}@", log: .watch, type: .info, "\(message)")

        if message["request"] != nil {
            let applicationDict = buildApplicationDict()
            replyHandler(applicationDict)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        os_log("Received message: %{PUBLIC}@", log: .watch, type: .info, message)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        os_log("activationDidCompleteWith activationState %{PUBLIC}@ error: %{PUBLIC}@", log: .watch, type: .info, "\(activationState)", "\(String(describing: error))")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        os_log("sessionDidBecomeInactive", log: .watch, type: .info)
    }

    func sessionDidDeactivate(_ session: WCSession) {
        os_log("sessionDidDeactivate", log: .watch, type: .info)
    }

    func buildApplicationDict() -> [String: Any] {
        let applicationDict: [String: Any] =
            [
                "localUrl": Preferences.localUrl,
                "remoteUrl": Preferences.remoteUrl,
                "username": Preferences.username,
                "password": Preferences.password,
                "alwaysSendCreds": Preferences.alwaysSendCreds,
                "defaultSitemap": "watch",
                "ignoreSSL": Preferences.ignoreSSL,
                "trustedCertificates": NetworkConnection.shared.serverCertificateManager.trustedCertificates
            ]

        return applicationDict
    }

    public func syncPreferencesToWatch() {
        if WCSession.default.activationState == .activated {
            let applicationDict = buildApplicationDict()
            try? WCSession.default.updateApplicationContext(applicationDict)
        }
    }
}
