//
//  AppPushService.swift
//  nightguard
//
//  Created by Dirk Hermanns on 01.06.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation
import WatchConnectivity
import WatchKit

// This class handles values that are passed from the ios app.
class AppMessageService: NSObject, WCSessionDelegate {

    static let singleton = AppMessageService()

    func updateValuesFromApplicationContext(_ applicationContext: [String: AnyObject]) {

        if let localUrl = applicationContext["localUrl"] as? String {
            Preferences.localUrl = localUrl
        }

        if let remoteUrl = applicationContext["remoteUrl"] as? String {
            Preferences.remoteUrl = remoteUrl
        }

        if let sitemapName = applicationContext["sitemapName"] as? String {
            Preferences.sitemapName = sitemapName
        }

        if let username = applicationContext["username"] as? String {
            Preferences.username = username
        }

        if let password = applicationContext["password"] as? String {
            Preferences.password = password
        }

        if let ignoreSSLCertificate = applicationContext["ignoreSSL"] as? Bool {
            Preferences.ignoreSSL = ignoreSSLCertificate
        }
    }

    @available(watchOSApplicationExtension 2.2, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {

        DispatchQueue.main.async { () -> Void in

            self.updateValuesFromApplicationContext(session.receivedApplicationContext as [String: AnyObject])
        }
    }

    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        updateValuesFromApplicationContext(applicationContext as [String: AnyObject])
    }

    /** Called on the delegate of the receiver. Will be called on startup if the user info finished transferring when the receiver was not running. */
    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        updateValuesFromApplicationContext(userInfo as [String: AnyObject])
    }

    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        updateValuesFromApplicationContext(message as [String: AnyObject])
    }

    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Swift.Void) {
        updateValuesFromApplicationContext(message as [String: AnyObject])
    }
}
