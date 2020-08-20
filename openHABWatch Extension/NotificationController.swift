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

import SwiftUI
import UserNotifications
import WatchKit

class NotificationController: WKUserNotificationHostingController<NotificationView> {
    var title: String?
    var message: String?

    let openHABMessageIndexKey = "openHABMessageIndex"

    override var body: NotificationView {
        NotificationView(customTextLabel: title, customDetailTextLabel: message)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    override func didReceive(_ notification: UNNotification) {
        // This method is called when a notification needs to be presented.

        _ = UserData()

        let notificationData = notification.request.content.userInfo as? [String: Any]

        let aps = notificationData?["aps"] as? [String: Any]

        let alert = aps?["alert"] as? [String: Any]

        title = alert?["title"] as? String
        message = alert?["body"] as? String

//        if let index = notificationData?[openHABMessageIndexKey] as? Int {
//            landmark = userData.landmarks[index]
//        }
    }
}
