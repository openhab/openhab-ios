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

import AlamofireNetworkActivityIndicator
import AVFoundation
import Firebase
import FirebaseMessaging
import Kingfisher
import OpenHABCore
import os.log
import SwiftMessages
import UIKit
import UserNotifications
import WatchConnectivity

var player: AVAudioPlayer?

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var appDelegate: AppDelegate!

    var window: UIWindow?
    var appData: OpenHABDataObject

    // Delegate Requests from the Watch to the WatchMessageService
    var session: WCSession? {
        didSet {
            if let session {
                session.delegate = WatchMessageService.singleton
                session.activate()
                os_log("Paired watch %{public}@, watch app installed %{public}@", log: .watch, type: .info, "\(session.isPaired)", "\(session.isWatchAppInstalled)")
            }
        }
    }

    override init() {
        appData = OpenHABDataObject()
        super.init()
        AppDelegate.appDelegate = self
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        os_log("didFinishLaunchingWithOptions started", log: .viewCycle, type: .info)

        setupFirebase()

        let appDefaults = ["CacheDataAgressively": NSNumber(value: true)]
        UserDefaults.standard.register(defaults: appDefaults)

        Preferences.migrateUserDefaultsIfRequired()

        NetworkConnection.initialize(ignoreSSL: Preferences.ignoreSSL, interceptor: OpenHABAccessTokenAdapter(appData: AppDelegate.appDelegate.appData))

        NetworkActivityIndicatorManager.shared.isEnabled = true
        NetworkActivityIndicatorManager.shared.startDelay = 1.0

        registerForPushNotifications()

        os_log("uniq id: %{public}s", log: .notifications, type: .info, UIDevice.current.identifierForVendor?.uuidString ?? "")
        os_log("device name: %{public}s", log: .notifications, type: .info, UIDevice.current.name)

        let audioSession = AVAudioSession.sharedInstance()
        do {
            if #available(iOS 10.0, *) {
                try audioSession.setCategory(.playback, mode: .default, options: [])
            }
        } catch {
            os_log("Setting category to AVAudioSessionCategoryPlayback failed.", log: .default, type: .info)
        }

        os_log("didFinishLaunchingWithOptions ended", log: .viewCycle, type: .info)

        activateWatchConnectivity()

        KingfisherManager.shared.defaultOptions = [.requestModifier(OpenHABAccessTokenAdapter(appData: AppDelegate.appDelegate.appData))]

        return true
    }

    private func setupFirebase() {
        // init Firebase crash reporting
        FirebaseApp.configure()
        FirebaseApp.app()?.isDataCollectionDefaultEnabled = false
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(Preferences.sendCrashReports)
        Messaging.messaging().delegate = self
    }

    func activateWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            os_log("WCSession is not supported - For instance on iPad", log: .watch, type: .debug)
        }
    }

    // Notification registration depends on iOS version
    // This is the setup for iOS >10 notifications
    func registerForPushNotifications() {
        #if DEBUG
        // do not request authorization if running UITest
        if ProcessInfo.processInfo.environment["UITest"] != nil {
            return
        }
        #endif

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            guard let self else { return }
            os_log("Permission granted: %{public}@", log: .notifications, type: .info, granted ? "YES" : "NO")
            guard granted else { return }
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                os_log("Notification settings: %{public}@", log: .notifications, type: .info, settings)

                guard settings.authorizationStatus == .authorized else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        UNUserNotificationCenter.current().delegate = self
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        // TODO: Pass this parameters to openHABViewController somehow to open specified sitemap/page and send specified command
        // Probably need to do this in a way compatible to Android app's URL

        os_log("Calling Application Bundle ID: %{public}@", log: .notifications, type: .info, options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String ?? "")
        os_log("URL scheme: %{public}@", log: .notifications, type: .info, url.scheme ?? "")
        os_log("URL query: %{public}@", log: .notifications, type: .info, url.query ?? "")

        if url.isFileURL {
            let clientCertificateManager = NetworkConnection.shared.clientCertificateManager
            return clientCertificateManager.startImportClientCertificate(url: url)
        }

        return true
    }

    // This is only informational - on success - DID Register
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Do nothing now, we are using FCM
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        os_log("Failed to get token for notifications: %{public}@", log: .notifications, type: .error, error.localizedDescription)
    }

    // this is called for "content-available" silent notifications (background notifications)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        os_log("didReceiveRemoteNotification %{public}@", log: .default, type: .info, userInfo)
        // Hide notification logic
        if let type = userInfo["type"] as? String, type == "hideNotification" {
            if let refid = userInfo["reference-id"] as? String {
                os_log("didReceiveRemoteNotification remove id %{public}@", log: .default, type: .info, refid)
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [refid])
            }
            if let tag = userInfo["tag"] as? String {
                UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                    let notificationsWithSeverity = notifications.filter { notification in
                        notification.request.content.userInfo["tag"] as? String == tag
                    }

                    // Get the identifiers of these notifications
                    let identifiers = notificationsWithSeverity.map(\.request.identifier)

                    if !identifiers.isEmpty {
                        os_log("didReceiveRemoteNotification remove tag %{public}@ %{public}@", log: .default, type: .info, tag, identifiers)
                        // Remove the filtered notifications
                        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
                    }
                }
            }
        }
        completionHandler(.newData)
    }

    // this is called when a notification comes in while in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        os_log("Notification received while app is in foreground: %{public}@", log: .notifications, type: .info, userInfo)
        appData.lastNotificationInfo = userInfo
        displayNotification(userInfo: userInfo)
        completionHandler([])
    }

    // this is called when clicking a notification while in the background
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        var userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        os_log("Notification clicked: action %{public}@ userInfo %{public}@", log: .notifications, type: .info, actionIdentifier, userInfo)
        if actionIdentifier != UNNotificationDismissActionIdentifier {
            if actionIdentifier != UNNotificationDefaultActionIdentifier {
                userInfo["actionIdentifier"] = actionIdentifier
            }
            notifyNotificationListeners(userInfo)
            appData.lastNotificationInfo = userInfo
        }
        completionHandler()
    }

    private func displayNotification(userInfo: [AnyHashable: Any]) {
        os_log("displayNotification %{public}@", log: .notifications, type: .info, userInfo["message"] as? String ?? "no message")

        let soundPath: URL? = Bundle.main.url(forResource: "ping", withExtension: "wav")
        if let soundPath {
            do {
                os_log("Sound path %{public}@", log: .notifications, type: .info, soundPath.debugDescription)
                player = try AVAudioPlayer(contentsOf: soundPath)
                player?.numberOfLoops = 0
                player?.play()
            } catch {
                os_log("%{public}@", log: .notifications, type: .error, error.localizedDescription)
            }
            player = try? AVAudioPlayer(contentsOf: soundPath)
        }

        let message = userInfo["message"] as? String ?? NSLocalizedString("message_not_decoded", comment: "")

        var config = SwiftMessages.Config()
        config.duration = .seconds(seconds: 5)
        config.presentationStyle = .bottom

        SwiftMessages.show(config: config) {
            let view = MessageView.viewFromNib(layout: .cardView)
            view.configureTheme(.info)
            view.configureContent(title: NSLocalizedString("notification", comment: ""), body: message)
            view.button?.setTitle(NSLocalizedString("dismiss", comment: ""), for: .normal)
            view.buttonTapHandler = { _ in SwiftMessages.hide() }
            // Add tap gesture recognizer to the view for actions
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.messageViewTapped))
            view.addGestureRecognizer(tapGesture)
            return view
        }
    }

    // Action to be performed when the notification message view is tapped
    @objc func messageViewTapped() {
        if let userInfo = appData.lastNotificationInfo {
            notifyNotificationListeners(userInfo)
            SwiftMessages.hideAll()
        }
    }

    private func notifyNotificationListeners(_ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(name: .apnsReceived, object: nil, userInfo: userInfo)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
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
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        os_log("My FCM token is: %{public}@", log: .notifications, type: .info, fcmToken ?? "")
        let dataDict = [
            "deviceToken": fcmToken ?? "",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "",
            "deviceName": UIDevice.current.name
        ]
        NotificationCenter.default.post(name: NSNotification.Name("apsRegistered"), object: self, userInfo: dataDict)
    }
}

extension Notification.Name {
    static let apnsReceived = Notification.Name("apnsReceived")
}
