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

    private var crashlyticsSubscriber: AnyCancellable?

    let notificationDelegate = NotificationCenterDelegateImpl()

    /// Delegate Requests from the Watch to the WatchMessageService
    var session: WCSession? {
        didSet {
            if let session {
                let watchMessageService = WatchMessageService.singleton
                session.delegate = watchMessageService
                session.activate()
                Logger.appDelegate.info("Paired watch \(session.isPaired), watch app installed \(session.isWatchAppInstalled)")
                Task {
                    await watchMessageService.subscribeToPreferences()
                }
            }
        }
    }

    override init() {
        super.init()
        AppDelegate.appDelegate = self
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Logger.appDelegate.info("didFinishLaunchingWithOptions started")

        // Only essential setup here - defer everything else to show UI faster
        let appDefaults = ["CacheDataAgressively": NSNumber(value: true)]
        UserDefaults.standard.register(defaults: appDefaults)

        Preferences.migratePreferences()

        // Firebase must be configured before the storyboard loads its root view controller,
        // because OpenHABRootViewController.viewDidLoad calls Crashlytics before the deferred
        // task would have had a chance to run. Calling Crashlytics before FirebaseApp.configure()
        // silences crash detection for the entire session.
        setupFirebase()

        UNUserNotificationCenter.current().delegate = notificationDelegate

        Logger.appDelegate.info("didFinishLaunchingWithOptions ended")

        // Defer non-essential initialization to after first frame renders
        Task { @MainActor in
            // Small delay to ensure UI has appeared
            try? await Task.sleep(for: .milliseconds(100))
            performDeferredSetup()
        }

        return true
    }

    /// Setup that can be deferred until after the UI appears
    @MainActor
    private func performDeferredSetup() {
        registerForPushNotifications()
        Logger.appDelegate.info("uniq id: \(UIDevice.current.identifierForVendor?.uuidString ?? "")")
        Logger.appDelegate.info("device name: \(UIDevice.current.name)")

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [])
        } catch {
            Logger.appDelegate.info("Setting category to AVAudioSessionCategoryPlayback failed.")
        }

        activateWatchConnectivity()

        configureImageCoders()
    }

    @MainActor
    func configureImageCoders() {
        let svgCoder = SDImageSVGCoder.shared
        SDImageCodersManager.shared.addCoder(svgCoder)
        Logger.appDelegate.info("SDImageSVGCoder registered")
    }

    private func setupFirebase() {
        // init Firebase crash reporting
        FirebaseApp.configure()
        FirebaseApp.app()?.isDataCollectionDefaultEnabled = false
        crashlyticsSubscriber = Preferences.shared.$sendCrashReports.sink {
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled($0)
            Logger.appDelegate.debug("setCrashlyticsCollectionEnabled to \($0)")
        }
        Messaging.messaging().delegate = self
    }

    func activateWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            Logger.appDelegate.debug("WCSession is not supported - For instance on iPad")
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
            Logger.appDelegate.info("Permission granted: \(granted ? "YES" : "NO")")
            guard granted else { return }
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                Logger.appDelegate.info("Notification settings: \(settings)")

                guard settings.authorizationStatus == .authorized else { return }
                Task { @MainActor in
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    /// This is only informational - on success - DID Register
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // TODO: remove before shipping
        // Logger.appDelegate.info("APNs token: \(deviceToken.map { String(format: "%02x", $0) }.joined())")
        // Do nothing now, we are using FCM
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        Logger.appDelegate.error("Failed to get token for notifications: \(error.localizedDescription)")
    }

    @MainActor
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        Logger.appDelegate.info("didReceiveRemoteNotification \(String(describing: userInfo), privacy: .public)")

        guard let type = userInfo["type"] as? String, type == "hideNotification" else {
            return .noData
        }

        if let refid = userInfo["reference-id"] as? String {
            Logger.appDelegate.info("Removing notification with id \(refid, privacy: .public)")
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
                Logger.appDelegate.info("Removing notifications with tag \(tag, privacy: .public), identifiers: \(String(describing: identifiers), privacy: .public)")
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
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}

extension AppDelegate: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            let safeToken = fcmToken ?? ""
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "UnknownDeviceID"
            let deviceName = UIDevice.current.name

            Logger.appDelegate.info("My FCM token is: \(safeToken, privacy: .private)")

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
