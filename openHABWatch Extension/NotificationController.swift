//
//  NotificationController.swift
//  openHABWatch Extension
//
//  Created by etrada on 13.05.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation
import UserNotifications
import WatchKit

class NotificationController: WKUserNotificationInterfaceController {
    override init() {
        // Initialize variables here.
        super.init()

        // Configure interface objects here.
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
        // Implement it if you use a dynamic notification interface.
        // Populate your dynamic notification interface as quickly as possible.
    }
}
