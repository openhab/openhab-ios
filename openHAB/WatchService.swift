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
import WatchConnectivity

class WatchService {
    static let singleton = WatchService()

    private var lastWatchUpdateTime: Date?
    private var lastWatchComplicationUpdateTime: Date?

    // swiftlint:disable:next function_parameter_count
    func sendToWatch(_ localUrl: String, remoteUrl: String,
                     username: String, password: String, alwaysSendCreds: Bool, sitemapName: String, ignoreSSL: Bool) {
        let applicationDict: [String: Any] =
            ["localUrl": localUrl,
             "remoteUrl": remoteUrl,
             "username": username,
             "password": password,
             "alwaysSendCreds": alwaysSendCreds,
             "sitemapName": sitemapName,
             "ignoreSSL": ignoreSSL]

        sendOrTransmitToWatch(applicationDict)
    }

    private func sendOrTransmitToWatch(_ message: [String: Any]) {
        // send message if watch is reachable
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { data in
                print("Received data: \(data)")
            }, errorHandler: { error in
                print(error)

                // transmit message on failure
                try? WCSession.default.updateApplicationContext(message)
            })
        } else {
            // otherwise, transmit application context
            try? WCSession.default.updateApplicationContext(message)
        }
    }
}
