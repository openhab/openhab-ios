// Copyright (c) 2010-2022 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

// Inspired by https://www.avanderlee.com/debugging/oslog-unified-logging/

import Foundation

import os.log

public extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Logs the view cycles like viewDidLoad.
    static let viewCycle = OSLog(subsystem: subsystem, category: "viewcycle")

    /// Logs the remote accesses
    static let remoteAccess = OSLog(subsystem: subsystem, category: "remoteAccess")

    /// Logs the URL composition
    static let urlComposition = OSLog(subsystem: subsystem, category: "urlComposition")

    /// Logs the notifications
    static let notifications = OSLog(subsystem: subsystem, category: "notifications")

    /// Logs watch connectivity
    static let watch = OSLog(subsystem: subsystem, category: "watch")

    /// Logs commands
    static let command = OSLog(subsystem: subsystem, category: "command")

    /// Logs decoding errors
    static let decoding = OSLog(subsystem: subsystem, category: "decoding")

    /// Logs Alamofire events
    static let alamofire = OSLog(subsystem: subsystem, category: "alamofire")

    /// Logs WkWebView events
    static let wkwebview = OSLog(subsystem: subsystem, category: "wkwebview")
}
