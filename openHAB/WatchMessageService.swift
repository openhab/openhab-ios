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
import OpenHABCore
import os.log
import WatchConnectivity

// This class receives Watch Request for the configuration data like localUrl.
// The functionality is activated in the AppDelegate.
class WatchMessageService: NSObject, WCSessionDelegate {
    static let singleton = WatchMessageService()

    // This method gets called when the watch requests the localUrl
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // TODO: Use RemoteUrl, TOO
        os_log("didReceive Message %{PUBLIC}@", log: .watch, type: .info, "\(message)")

        if message["requestLocalUrl"] != nil {
            replyHandler(["baseUri": Preferences.localUrl])
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        os_log("Received message: %{PUBLIC}@", log: .default, type: .info, message)
    }

    @available(iOS 9.3, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {}
}
