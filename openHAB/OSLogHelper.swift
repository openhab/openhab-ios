//
//  OSLogHelper.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 01.04.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

// Inspired by https://www.avanderlee.com/debugging/oslog-unified-logging/

import Foundation

import os.log

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Logs the view cycles like viewDidLoad.
    static let viewCycle = OSLog(subsystem: subsystem, category: "viewcycle")

    /// Logs the remote accesses
    static let remoteAccess = OSLog(subsystem: subsystem, category: "remoteAccess")

    /// Logs the URL composition
    static let urlComposition = OSLog(subsystem: subsystem, category: "urlComposition")

    /// Logs the notifications
    static let notifications = OSLog(subsystem: subsystem, category: "notifications")
}
