// Copyright (c) 2010-2026 Contributors to the openHAB project
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

public extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "org.openhab.app"

    static let appDelegate = Logger(subsystem: subsystem, category: "AppDelegate")

    static let carPlay = Logger(subsystem: subsystem, category: "CarPlay")

    static let clientCert = Logger(subsystem: subsystem, category: "ClientCert")

    static let connectionFailureTracker = Logger(subsystem: subsystem, category: "ConnectionFailureTracker")

    static let defaultLoggingMiddleware = Logger(subsystem: subsystem, category: "loggingMiddleware")

    static let drawerView = Logger(subsystem: subsystem, category: "DrawerView")

    static let endpoint = Logger(subsystem: subsystem, category: "EndPoint")

    static let etagCache = Logger(subsystem: subsystem, category: "ETagCache")

    static let etagChecker = Logger(subsystem: subsystem, category: "ETagChecker")

    static let httpClient = Logger(subsystem: subsystem, category: "HTTPClient")

    static let httpClientDelegate = Logger(subsystem: subsystem, category: "HTTPClientDelegate")

    static let intentHandling = Logger(subsystem: subsystem, category: "IntentHandling")

    static let itemCache = Logger(subsystem: subsystem, category: "OpenHABItemCache")

    static let networkTracker = Logger(subsystem: subsystem, category: "NetworkTracker")

    static let notificationService = Logger(subsystem: subsystem, category: "NotificationService")

    static let notificationCenterDelegateImpl = Logger(subsystem: subsystem, category: "NotificationCenterDelegateImpl")

    static let nwPathMonitoring = Logger(subsystem: subsystem, category: "NWPathMonitoring")

    static let openAPIService = Logger(subsystem: subsystem, category: "OpenAPIService")

    static let openHABImageProcessor = Logger(subsystem: subsystem, category: "OpenHABImageProcessor")

    static let pageLoader = Logger(subsystem: subsystem, category: "PageLoader")

    static let sitemapPageLoader = Logger(subsystem: subsystem, category: "SitemapPageLoader")

    static let preferences = Logger(subsystem: subsystem, category: "Preferences")

    static let restAPI = Logger(subsystem: subsystem, category: "RestAPI")

    static let rowViews = Logger(subsystem: subsystem, category: "RowViews")

    static let screenSaver = Logger(subsystem: subsystem, category: "ScreenSaver")

    static let selectionView = Logger(subsystem: subsystem, category: "SelectionView")

    static let sessionChallenge = Logger(subsystem: subsystem, category: "SessionChallenge")

    static let sessionChallengeHandler = Logger(subsystem: subsystem, category: "SessionChallengeHandler")

    static let serverCert = Logger(subsystem: subsystem, category: "ServerCertificateManager")

    static let settingsView = Logger(subsystem: subsystem, category: "SettingsView")

    static let sitemapViewController = Logger(subsystem: subsystem, category: "SitemapViewController")

    static let userData = Logger(subsystem: subsystem, category: "UserData")

    static let videoProcessing = Logger(subsystem: subsystem, category: "VideoProcessing")

    static let viewController = Logger(subsystem: subsystem, category: "viewController")

    static let widgets = Logger(subsystem: subsystem, category: "Widgets")

    static let rtfTextView = Logger(subsystem: subsystem, category: "RTFTextView")

    static let watchService = Logger(subsystem: subsystem, category: "WatchService")

    static let watchInterface = Logger(subsystem: subsystem, category: "WatchInterface")
}
