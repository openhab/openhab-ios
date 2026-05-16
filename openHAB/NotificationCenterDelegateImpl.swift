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
        let actions = Self.parseActionItems(userInfo["actions"] as? String)
        await displayNotification(message: message, action: action, cloudUserId: cloudUserId, actions: actions)

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

    private func displayNotification(message: String, action: String?, cloudUserId: String?, actions: [NotificationActionItem] = []) async {
        Logger.notificationCenterDelegateImpl.info("displayNotification \(message)")

        Task {
            await audioPlayer.playSound()
        }

        let title = String(localized: "notification", comment: "")
        ToastService.shared.show(
            title: title,
            message: message,
            actions: actions,
            onTap: { [weak self] in
                self?.notifyNotificationListeners(action: action, cloudUserId: cloudUserId)
            },
            onAction: { [weak self] item in
                self?.notifyNotificationListeners(action: item.action, cloudUserId: cloudUserId)
            }
        )
    }

    private static func parseActionItems(_ json: String?) -> [NotificationActionItem] {
        guard let json,
              let data = json.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else { return [] }
        return raw.compactMap { dict in
            guard let title = dict["title"], let action = dict["action"] else { return nil }
            return NotificationActionItem(title: title, action: action)
        }
    }

    @MainActor
    func notifyNotificationListeners(action: String?, cloudUserId: String? = nil) {
        // Wake up screen saver immediately on incoming notification interaction
        NotificationCenter.default.post(name: .wakeScreenSaver, object: nil)

        // Post notification for AppServicesViewModel (or legacy OpenHABRootViewController) to handle
        NotificationCenter.default.post(
            name: .openHABHandleNotificationAction,
            object: nil,
            userInfo: [
                "action": action as Any,
                "cloudUserId": cloudUserId as Any
            ]
        )
    }
}

extension UNUserNotificationCenter: @retroactive @unchecked Sendable {}
extension UNNotificationResponse: @retroactive @unchecked Sendable {}
extension UNNotification: @retroactive @unchecked Sendable {}
