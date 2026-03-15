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

actor AudioPlayerActor {
    private var player: AVAudioPlayer?

    func playSound() {
        guard let soundPath = Bundle.main.url(forResource: "ping", withExtension: "wav") else {
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: soundPath)
            newPlayer.numberOfLoops = 0
            newPlayer.play()
            player = newPlayer
        } catch {
            Logger.notificationCenterDelegateImpl.info("Failed to play sound \(error.localizedDescription)")
        }
    }

    func stopSound() {
        player?.stop()
    }
}

@MainActor
final class NotificationCenterDelegateImpl: NSObject, UNUserNotificationCenterDelegate {
    let audioPlayer = AudioPlayerActor()

    // this is called when a notification comes in while in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        Logger.notificationCenterDelegateImpl.info("Notification received while app is in foreground: \(userInfo)")

        NotificationCenter.default.post(
            name: .openHABDidReceiveNotification,
            object: nil,
            userInfo: userInfo
        )

        let message = userInfo["message"] as? String ?? String(localized: "message_not_decoded", comment: "")
        let action = userInfo["actionIdentifier"] as? String ?? userInfo["on-click"] as? String
        let cloudUserId = userInfo["userId"] as? String
        await displayNotification(message: message, action: action, cloudUserId: cloudUserId)

        return [] // Modify this if you want to show banners, alerts, etc.
    }

    // this is called when clicking a notification while in the background
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        var userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        Logger.notificationCenterDelegateImpl.info("Notification clicked: action \(actionIdentifier) userInfo \(userInfo)")

        if actionIdentifier != UNNotificationDismissActionIdentifier {
            if actionIdentifier != UNNotificationDefaultActionIdentifier {
                userInfo["actionIdentifier"] = actionIdentifier
            }
            let action = userInfo["actionIdentifier"] as? String ?? userInfo["on-click"] as? String
            let cloudUserId = userInfo["userId"] as? String

            notifyNotificationListeners(action: action, cloudUserId: cloudUserId)
        }
    }

    private func displayNotification(message: String, action: String?, cloudUserId: String?) async {
        Logger.notificationCenterDelegateImpl.info("displayNotification \(message)")

        Task {
            await audioPlayer.playSound()
        }

        var config = SwiftMessages.Config()
        config.duration = .seconds(seconds: 5)
        config.presentationStyle = .bottom

        class MessageTapGestureRecognizer: UITapGestureRecognizer {
            private let handler: () -> Void

            init(handler: @escaping () -> Void) {
                self.handler = handler
                super.init(target: nil, action: nil)
                addTarget(self, action: #selector(handleTap))
            }

            @objc private func handleTap() {
                handler()
            }
        }

        await MainActor.run {
            SwiftMessages.show(config: config) {
                let view = MessageView.viewFromNib(layout: .cardView)
                view.configureTheme(.info)
                view.configureContent(title: String(localized: "notification", comment: ""), body: message)
                view.button?.setTitle(String(localized: "dismiss", comment: ""), for: .normal)
                view.buttonTapHandler = { _ in SwiftMessages.hide() }

                // Use closure-based tap gesture insteae of #selector
                let tapGesture = MessageTapGestureRecognizer {
                    Task {
                        await self.messageViewTapped(action: action, cloudUserId: cloudUserId)
                    }
                }
                view.addGestureRecognizer(tapGesture)

                return view
            }
        }
    }

    // Action to be performed when the notification message view is tapped
    func messageViewTapped(action: String?, cloudUserId: String? = nil) async {
        notifyNotificationListeners(action: action, cloudUserId: cloudUserId)
        SwiftMessages.hideAll()
    }

    // ✅ Ensure this runs on the MainActor
    @MainActor
    func notifyNotificationListeners(action: String?, cloudUserId: String? = nil) {
        // Wake up screen saver immediately on incoming notification interaction
        NotificationCenter.default.post(name: .wakeScreenSaver, object: nil)

        if let navigationController = AppDelegate.appDelegate.window?.rootViewController as? UINavigationController,
           let rootViewController = navigationController.viewControllers.first as? OpenHABRootViewController {
            rootViewController.handleNotification(action: action, cloudUserId: cloudUserId)
        }
    }
}

extension UNUserNotificationCenter: @retroactive @unchecked Sendable {}
extension UNNotificationResponse: @retroactive @unchecked Sendable {}
extension UNNotification: @retroactive @unchecked Sendable {}
