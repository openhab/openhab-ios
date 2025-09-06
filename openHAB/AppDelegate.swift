// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import AVFoundation
import Combine
import Firebase
import FirebaseMessaging
import Kingfisher
import OpenHABCore
import os.log
import SDWebImageSVGCoder
import SwiftMessages
import UIKit
@preconcurrency import UserNotifications
import WatchConnectivity

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    static var appDelegate: AppDelegate!

    private let logger = Logger(subsystem: "org.openhab", category: "AppDelegate")

    var window: UIWindow?

    private var crashlyticsSubscriber: AnyCancellable?

    private let notificationDelegate = NotificationCenterDelegateImpl()

    // Delegate Requests from the Watch to the WatchMessageService
    var session: WCSession? {
        didSet {
            if let session {
                let watchMessageService = WatchMessageService.singleton
                session.delegate = watchMessageService
                session.activate()
                logger.info("Paired watch \(session.isPaired), watch app installed \(session.isWatchAppInstalled)")
                watchMessageService.subscribeToPreferences()
            }
        }
    }

    override init() {
        super.init()
        AppDelegate.appDelegate = self
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        logger.info("didFinishLaunchingWithOptions started")

        setupFirebase()

        let appDefaults = ["CacheDataAgressively": NSNumber(value: true)]
        UserDefaults.standard.register(defaults: appDefaults)

        Preferences.migratePreferences()

        UNUserNotificationCenter.current().delegate = notificationDelegate

        registerForPushNotifications()
        logger.info("uniq id: \(UIDevice.current.identifierForVendor?.uuidString ?? "")")
        logger.info("device name: \(UIDevice.current.name)")

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [])
        } catch {
            logger.info("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
        logger.info("didFinishLaunchingWithOptions ended")

        activateWatchConnectivity()

        configureImageCoders()

        /// load and start the screensaver
        if let keyWindow = UIApplication.shared.firstKeyWindow {
            var config = ScreenSaverConfiguration()
            config.isEnabled = Preferences.screensaverEnabled
            config.showsTime = Preferences.screensaverShowsTime
            config.showsDate = Preferences.screensaverShowsDate
            config.idleInterval = Preferences.screensaverIdleInterval
            config.movementInterval = Preferences.screensaverMovementInterval
            config.fontName = Preferences.screensaverFontName.isEmpty ? nil : Preferences.screensaverFontName
            config.timeFontSizeRatio = CGFloat(Preferences.screensaverTimeFontRatio)
            config.dateFontRelativeSize = CGFloat(Preferences.screensaverDateFontRatio)
            config.enablesAutoDimming = Preferences.screensaverEnableDimming
            config.dimLevel = CGFloat(Preferences.screensaverDimLevel)
            config.wakeBrightnessLevel = CGFloat(Preferences.screensaverWakeBrightness)
            config.showsSeconds = Preferences.screensaverShowsSeconds
            config.uses24HourTime = Preferences.screensaverUse24Hour
            config.restoresBrightness = Preferences.screensaverRestoreBrightness

            ScreenSaverManager.shared.startMonitoring(window: keyWindow, configuration: config)
        }

        return true
    }

    @MainActor
    func configureImageCoders() {
        let svgCoder = SDImageSVGCoder.shared
        SDImageCodersManager.shared.addCoder(svgCoder)
        logger.info("SDImageSVGCoder registered")
    }

    private func setupFirebase() {
        // init Firebase crash reporting
        FirebaseApp.configure()
        FirebaseApp.app()?.isDataCollectionDefaultEnabled = false
        crashlyticsSubscriber = Preferences.$sendCrashReports.sink { [weak self] in
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled($0)
            self?.logger.debug("setCrashlyticsCollectionEnabled to \($0)")
        }
        Messaging.messaging().delegate = self
    }

    func activateWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            logger.debug("WCSession is not supported - For instance on iPad")
        }
    }

    nonisolated func registerForPushNotifications() {
        #if DEBUG
        // do not request authorization if running UITest
        if ProcessInfo.processInfo.environment["UITest"] != nil {
            return
        }
        #endif

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            self.logger.info("Permission granted: \(granted ? "YES" : "NO")")
            guard granted else { return }
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                self.logger.info("Notification settings: \(settings)")

                guard settings.authorizationStatus == .authorized else { return }
                Task { @MainActor in
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        // TODO: Pass this parameters to openHABViewController somehow to open specified sitemap/page and send specified command
        // Probably need to do this in a way compatible to Android app's URL
        logger.info("Calling Application Bundle ID: \(options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String ?? "")")
        logger.info("URL: \(url.absoluteString)")
        logger.info("URL scheme: \(url.scheme ?? "")")
        logger.info("URL query: \(url.query ?? "")")

        if url.isFileURL {
            logger.info("Loading Certificate")
            let clientCertificateManager = CertificateManagers.clientCertificateManager
            Task { @MainActor in
                await clientCertificateManager.startImportClientCertificate(url: url)
            }
            return true
        }

        // remove the 'openhab' from the url
        let action = url.absoluteString.split(separator: ":").dropFirst().joined(separator: ":")
        notificationDelegate.notifyNotificationListeners(action: action)
        return true
    }

    // This is only informational - on success - DID Register
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Do nothing now, we are using FCM
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        logger.error("Failed to get token for notifications: \(error.localizedDescription)")
    }

    @MainActor
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        logger.info("didReceiveRemoteNotification \(String(describing: userInfo), privacy: .public)")

        guard let type = userInfo["type"] as? String, type == "hideNotification" else {
            return .noData
        }

        if let refid = userInfo["reference-id"] as? String {
            logger.info("Removing notification with id \(refid, privacy: .public)")
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [refid])
        }

        if let tag = userInfo["tag"] as? String {
            // Hop off the MainActor to avoid Sendable warning
            let identifiers: [String] = await Task.detached(priority: .userInitiated) {
                let notifications = await UNUserNotificationCenter.current().deliveredNotifications()
                return notifications
                    .filter { $0.request.content.userInfo["tag"] as? String == tag }
                    .map(\.request.identifier)
            }.value

            if !identifiers.isEmpty {
                logger.info("Removing notifications with tag \(tag, privacy: .public), identifiers: \(String(describing: identifiers), privacy: .public)")
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }

        return .newData
    }
}

extension Notification.Name {
    static let openHABDidReceiveNotification = Notification.Name("openHABDidReceiveNotification")
}

extension AppDelegate {
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        NotificationCenter.default.post(name: .disableScreenSaver, object: nil)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if let keyWindow = UIApplication.shared.firstKeyWindow {
            var config = ScreenSaverConfiguration()
            config.isEnabled = Preferences.screensaverEnabled
            config.showsTime = Preferences.screensaverShowsTime
            config.showsDate = Preferences.screensaverShowsDate
            config.idleInterval = Preferences.screensaverIdleInterval
            config.movementInterval = Preferences.screensaverMovementInterval
            config.fontName = Preferences.screensaverFontName.isEmpty ? nil : Preferences.screensaverFontName
            config.timeFontSizeRatio = CGFloat(Preferences.screensaverTimeFontRatio)
            config.dateFontRelativeSize = CGFloat(Preferences.screensaverDateFontRatio)
            config.enablesAutoDimming = Preferences.screensaverEnableDimming
            config.dimLevel = CGFloat(Preferences.screensaverDimLevel)
            config.wakeBrightnessLevel = CGFloat(Preferences.screensaverWakeBrightness)
            config.showsSeconds = Preferences.screensaverShowsSeconds
            config.uses24HourTime = Preferences.screensaverUse24Hour
            config.restoresBrightness = Preferences.screensaverRestoreBrightness

            ScreenSaverManager.shared.startMonitoring(window: keyWindow, configuration: config)
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

extension AppDelegate: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            let safeToken = fcmToken ?? ""
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "UnknownDeviceID"
            let deviceName = UIDevice.current.name

            logger.info("My FCM token is: \(safeToken, privacy: .private)")

            let dataDict: [String: Any] = [
                "deviceToken": safeToken,
                "deviceId": deviceID,
                "deviceName": deviceName
            ]

            NotificationCenter.default.post(
                name: NSNotification.Name("apsRegistered"),
                object: self,
                userInfo: dataDict
            )
        }
    }
}
