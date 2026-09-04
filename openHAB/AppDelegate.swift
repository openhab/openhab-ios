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
import CarPlay
import Combine
import Firebase
import FirebaseMessaging
import Kingfisher
import OpenHABCore
import os.log
import SDWebImageSVGCoder
import UIKit
@preconcurrency import UserNotifications
import WatchConnectivity

class AppDelegate: UIResponder, UIApplicationDelegate {

    private var crashlyticsTask: Task<Void, Never>?

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
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Logger.appDelegate.info("didFinishLaunchingWithOptions started")

        // Only essential setup here - defer everything else to show UI faster
        let appDefaults = ["CacheDataAgressively": NSNumber(value: true)]
        UserDefaults.standard.register(defaults: appDefaults)

        Task { _ = await Preferences.shared.listStoredHomes() }
        SitemapDiagnostics.markProcessLaunch(source: launchSource(launchOptions))

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

    private func launchSource(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> String {
        guard let launchOptions, !launchOptions.isEmpty else { return "user" }
        if launchOptions[.remoteNotification] != nil {
            return "remoteNotification"
        }
        if launchOptions[.url] != nil {
            return "url"
        }
        if launchOptions[.location] != nil {
            return "location"
        }
        return "other"
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

        // load and start the screensaver
        if let keyWindow = UIApplication.shared.firstKeyWindow {
            Task { @MainActor in
                var config = ScreenSaverConfiguration()
                config.isEnabled = await Preferences.shared.screensaverEnabled
                config.showsTime = await Preferences.shared.screensaverShowsTime
                config.showsDate = await Preferences.shared.screensaverShowsDate
                config.idleInterval = await Preferences.shared.screensaverIdleInterval
                config.movementInterval = await Preferences.shared.screensaverMovementInterval
                let fontName = await Preferences.shared.screensaverFontName
                config.fontName = fontName.isEmpty ? nil : fontName
                config.timeFontSizeRatio = CGFloat(await Preferences.shared.screensaverTimeFontRatio)
                config.dateFontRelativeSize = CGFloat(await Preferences.shared.screensaverDateFontRatio)
                config.enablesAutoDimming = await Preferences.shared.screensaverEnableDimming
                config.dimLevel = CGFloat(await Preferences.shared.screensaverDimLevel)
                config.wakeBrightnessLevel = CGFloat(await Preferences.shared.screensaverWakeBrightness)
                config.showsSeconds = await Preferences.shared.screensaverShowsSeconds
                config.uses24HourTime = await Preferences.shared.screensaverUse24Hour
                config.restoresBrightness = await Preferences.shared.screensaverRestoreBrightness
                ScreenSaverManager.shared.startMonitoring(window: keyWindow, configuration: config)
            }
        }
        // Start monitoring items for widget updates after the app is configured.
        WidgetItemMonitor.shared.startMonitoring()
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
        crashlyticsTask = Task {
            for await value in await Preferences.shared.sendCrashReportsStream {
                Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(value)
                Logger.appDelegate.debug("setCrashlyticsCollectionEnabled to \(value)")
            }
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
    func applicationWillResignActive(_ application: UIApplication) {
        // Dismiss the screensaver overlay and restore brightness before the app leaves the
        // foreground (Control Center, an incoming call, the app switcher, backgrounding, etc.),
        // rather than leaving that cleanup to happen reactively on the next touch.
        NotificationCenter.default.post(name: .disableScreenSaver, object: nil)
    }

    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        false
    }

    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        // Explicitly opt out of UIKit state restoration. Without this, iOS defaults to
        // attempting to restore any previously-saved archive for backward compatibility --
        // including one saved by an older, storyboard-based build (pre-SwiftUI app lifecycle,
        // see 6d89e35a). On a device upgraded in place from that older build, iOS tries to
        // restore view controllers/storyboard IDs that no longer exist, producing a black,
        // unresponsive screen with nothing logged (the failure happens before app code runs).
        false
    }

    // Info.plist sets UIApplicationSupportsSecureRestorableState, which makes iOS consult these
    // NSSecureCoding-based methods instead of the deprecated pair above. Both pairs are kept in
    // sync (both false) since which one iOS actually calls depends on that flag; the deprecated
    // pair stays as a defensive fallback.
    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        false
    }

    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        false
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        switch connectingSceneSession.role {
        case .carTemplateApplication:
            UISceneConfiguration(name: "CarPlay Configuration", sessionRole: connectingSceneSession.role)
        default:
            // Named distinctly from the old "Default Configuration" (storyboard-based
            // SceneDelegate + Main.storyboard, removed in 6d89e35a): reusing that name would
            // let iOS try to reconnect a UISceneSession cached from a build that had it,
            // referencing a scene delegate/storyboard that no longer exists. A new name forces
            // a fresh session instead of a reconnection attempt on in-place upgrade.
            UISceneConfiguration(name: "SwiftUI Configuration", sessionRole: connectingSceneSession.role)
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if let keyWindow = UIApplication.shared.firstKeyWindow {
            Task { @MainActor in
                let ssPrefs = await Preferences.shared.screensaverPreferences()
                var config = ScreenSaverConfiguration()
                config.isEnabled = ssPrefs.isEnabled
                config.showsTime = ssPrefs.showsTime
                config.showsDate = ssPrefs.showsDate
                config.idleInterval = ssPrefs.idleInterval
                config.movementInterval = ssPrefs.movementInterval
                config.fontName = ssPrefs.fontName.isEmpty ? nil : ssPrefs.fontName
                config.timeFontSizeRatio = CGFloat(ssPrefs.timeFontSizeRatio)
                config.dateFontRelativeSize = CGFloat(ssPrefs.dateFontRelativeSize)
                config.enablesAutoDimming = ssPrefs.enablesAutoDimming
                config.dimLevel = CGFloat(ssPrefs.dimLevel)
                config.wakeBrightnessLevel = CGFloat(ssPrefs.wakeBrightnessLevel)
                config.showsSeconds = ssPrefs.showsSeconds
                config.uses24HourTime = ssPrefs.uses24HourTime
                config.restoresBrightness = ssPrefs.restoresBrightness
                ScreenSaverManager.shared.startMonitoring(window: keyWindow, configuration: config)
            }
        }

        Task {
            await WidgetItemMonitor.shared.cleanupStaleItems()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
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
