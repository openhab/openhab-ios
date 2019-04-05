//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  OpenHABAppDelegate.swift
//  openHAB
//
//  Created by Victor Belov on 12/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import AVFoundation
import Firebase
import UIKit
import UserNotifications
import os.log

var player: AVAudioPlayer?

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var appData: OpenHABDataObject?

    override init() {
        appData = OpenHABDataObject()
        super.init()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        os_log("didFinishLaunchingWithOptions started", log: .viewCycle, type: .info)

        //init Firebase crash reporting
        FirebaseApp.configure()

        let appDefaults = ["CacheDataAgressively": NSNumber(value: true)]

        UserDefaults.standard.register(defaults: appDefaults)

        loadSettingsDefaults()

        AFRememberingSecurityPolicy.initializeCertificatesStore()

        registerForPushNotifications()

        os_log("uniq id: %{PUBLIC}@", log: .notifications, type: .info, UIDevice.current.identifierForVendor?.uuidString ?? "")
        os_log("device name: %{PUBLIC}@", log: .notifications, type: .info, UIDevice.current.name)

        let audioSession = AVAudioSession.sharedInstance()
        do {
            if #available(iOS 10.0, *) {
                try audioSession.setCategory(.playback, mode: .default, options: [])
            }
        } catch {
            os_log("Setting category to AVAudioSessionCategoryPlayback failed.", log: .default, type: .info)
        }

        os_log("didFinishLaunchingWithOptions ended", log: .viewCycle, type: .info)

        return true
    }

    // Notification registration depends on iOS version
    // This is the setup for iOS >10 notifications
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            guard let self = self else { return }
            os_log("Permission granted: %{PUBLIC}@", log: .notifications, type: .info, granted ? "YES" : "NO")
            guard granted else { return }
            self.getNotificationSettings()
        }

    }

    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            os_log("Notification settings: %{PUBLIC}@", log: .notifications, type: .info, settings)

            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        // TODO: Pass this parameters to openHABViewController somehow to open specified sitemap/page and send specified command
        // Probably need to do this in a way compatible to Android app's URL

        os_log("Calling Application Bundle ID: %{PUBLIC}@", log: .notifications, type: .info, sourceApplication ?? "")
        os_log("URL scheme: %{PUBLIC}@", log: .notifications, type: .info, url.scheme ?? "")
        os_log("URL query: %{PUBLIC}@", log: .notifications, type: .info, url.query ?? "")

        if url.isFileURL {
            let clientCertificateManager = OpenHABHTTPRequestOperation.clientCertificateManager
            clientCertificateManager.delegate = appData!.rootViewController!
            return clientCertificateManager.startImportClientCertificate(url: url)
        }

        return true
    }

    // This is only informational - on success - DID Register
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)}) //try "%02.2hhx",

        os_log("My token is: %{PUBLIC}@", log: .notifications, type: .info, deviceTokenString)

        let dataDict = [
            "deviceToken": deviceTokenString,
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "" ,
            "deviceName": UIDevice.current.name
        ]
        NotificationCenter.default.post(name: NSNotification.Name("apsRegistered"), object: self, userInfo: dataDict)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        os_log("Failed to get token for notifications: %{PUBLIC}@", log: .notifications, type: .error, error.localizedDescription)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // version without completionHandler is deprecated
    //func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        os_log("didReceiveRemoteNotification", log: .notifications, type: .info)

        if application.applicationState == .active {
            os_log("App is active and got a remote notification", log: .notifications, type: .info)

            guard let aps = userInfo["aps"] as? [String: AnyObject] else {
                completionHandler(.failed)
                return
            }

            let soundPath: URL? = Bundle.main.url(forResource: "ping", withExtension: "wav")
            if let soundPath = soundPath {
                do {
                    os_log("Sound path %{PUBLIC}@", log: .notifications, type: .info, soundPath.debugDescription)

                    player = try AVAudioPlayer(contentsOf: soundPath)
                    player?.numberOfLoops = 0
                    player?.play()
                } catch let error {
                    os_log("%{PUBLIC}@", log: .notifications, type: .error, error.localizedDescription)
                }
                player = try? AVAudioPlayer(contentsOf: soundPath)
            }
            os_log("%{PUBLIC}@", log: .notifications, type: .info, aps)

            let message = (aps["alert"] as? [String: String])?["body"] ?? "Message could not be decoded"
            TSMessage.showNotification(in: ((window?.rootViewController as? MMDrawerController)?.centerViewController as? UINavigationController)?.visibleViewController, title: "Notification", subtitle: message, image: nil, type: TSMessageNotificationType.message, duration: 5.0, callback: nil, buttonTitle: nil, buttonCallback: nil, at: TSMessageNotificationPosition.bottom, canBeDismissedByUser: true)

        }
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

    func loadSettingsDefaults() {
        let prefs = UserDefaults.standard
        if prefs.object(forKey: "localUrl") == nil {
            prefs.setValue("", forKey: "localUrl")
        }
        if prefs.object(forKey: "remoteUrl") == nil {
            prefs.setValue("", forKey: "remoteUrl")
        }
        if prefs.object(forKey: "username") == nil {
            prefs.setValue("", forKey: "username")
        }
        if prefs.object(forKey: "password") == nil {
            prefs.setValue("", forKey: "password")
        }
        if prefs.object(forKey: "ignoreSSL") == nil {
            prefs.set(false, forKey: "ignoreSSL")
        }
        if prefs.object(forKey: "demomode") == nil {
            prefs.set(true, forKey: "demomode")
        }
        if prefs.object(forKey: "idleOff") == nil {
            prefs.set(false, forKey: "idleOff")
        }
        if prefs.object(forKey: "iconType") == nil {
            prefs.set(false, forKey: "iconType")
        }

    }
}
