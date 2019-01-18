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

var player: AVAudioPlayer?

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var appData: OpenHABDataObject?

    override init() {
        appData = OpenHABDataObject()
        super.init()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("didFinishLaunchingWithOptions started")

        //init Firebase crash reporting
        FirebaseApp.configure()

        //    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        //    manager.operationQueue.maxConcurrentOperationCount = 50;
        let appDefaults = ["CacheDataAgressively" : NSNumber(value: true)]
        if let appDefaults = appDefaults as? [String : Any] {
            UserDefaults.standard.register(defaults: appDefaults)
        }
        loadSettingsDefaults()
        AFRememberingSecurityPolicy.initializeCertificatesStore()
        // Notification registration now depends on iOS version (befor iOS8 and after it)
        // iOS 8 Notifications
        UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil))
        UIApplication.shared.registerForRemoteNotifications()

        print("uniq id \(UIDevice.current.identifierForVendor?.uuidString ?? "")")
        print("device name \(UIDevice.current.name)")

        let audioSession = AVAudioSession.sharedInstance()
        do {
            if #available(iOS 10.0, *) {
                try audioSession.setCategory(.playback, mode: .default, options: [])
            }
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }

        print("didFinishLaunchingWithOptions ended")
        return true
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        // TODO: Pass this parameters to openHABViewController somehow to open specified sitemap/page and send specified command
        // Probably need to do this in a way compatible to Android app's URL
        print("Calling Application Bundle ID: \(sourceApplication ?? "")")
        print("URL scheme:\(url.scheme ?? "")")
        print("URL query: \(url.query ?? "")")

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("My token is: \(deviceToken.hexString())")
        let dataDict = [
            "deviceToken": deviceToken.hexString(),
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "" ,
            "deviceName": UIDevice.current.name
        ]
        NotificationCenter.default.post(name: NSNotification.Name("apsRegistered"), object: self, userInfo: dataDict)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to get token, error: \(error)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        print("didReceiveRemoteNotification")
        if application.applicationState == .active {
            print("App is active and got a remote notification")
            if let value = userInfo["aps"] {
                print("\(value)")
            }
            let message = ((userInfo["aps"] as? [String:String])?["alert"] as? [String:String])?["body"]
            let soundPath: URL? = Bundle.main.url(forResource: "ping", withExtension: "wav")
            if let soundPath = soundPath {
                print("Sound path \(soundPath)")
            }
            if let soundPath = soundPath {
                player = try? AVAudioPlayer(contentsOf: soundPath)
            }
            if player != nil {
                player?.numberOfLoops = 0
                player?.play()
            } else {
                print("AVPlayer error")
            }
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
        var prefs = UserDefaults.standard
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
    }
}
