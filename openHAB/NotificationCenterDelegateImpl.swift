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

/// AVAudioPlayer must be created, used, and deallocated on the main thread.
/// Using a plain `actor` placed it on a background executor, causing a crash when
/// AVFoundation delivered finishedPlaying: on the main thread while the old player
/// was simultaneously being deallocated on the actor's background thread (mutex contention
/// in AVAudioPlayerCpp::DoAction / disposeQueue). @MainActor pins the entire lifecycle.
@MainActor
final class AudioPlayerActor {
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

        let payload = PushNotificationPayload(userInfo: userInfo)

        NotificationCenter.default.post(
            name: .openHABDidReceiveNotification,
            object: payload,
            userInfo: userInfo
        )

        // Suppress silent control messages — they carry no user-visible content (develop ab7278f9 #1226)
        guard !payload.isHideNotification else { return [] }

        // Return system banner when media attachments are present so the image is visible.
        // Checks content.attachments (fetched by the notification service extension) rather than
        // the raw URL field, matching develop ab7278f9 #1226.
        if !notification.request.content.attachments.isEmpty {
            return [.banner, .sound]
        }

        let actions = payload.actions?.map { NotificationActionItem(title: $0.title, action: $0.action) } ?? []
        await displayNotification(message: payload.displayMessage, action: payload.action, cloudUserId: payload.cloudUserId, actions: actions)

        return []
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

            // Pass the original notification so action handlers can re-post it on failure,
            // allowing the user to retry without waiting for a new notification.
            notifyNotificationListeners(action: action, cloudUserId: cloudUserId, notification: response.notification)
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
    func notifyNotificationListeners(action: String?, cloudUserId: String? = nil, notification: UNNotification? = nil) {
        // Wake up screen saver immediately on incoming notification interaction
        NotificationCenter.default.post(name: .wakeScreenSaver, object: nil)

        // Post notification for NotificationActionService to handle
        NotificationCenter.default.post(
            name: .openHABHandleNotificationAction,
            object: nil,
            userInfo: [
                "action": action as Any,
                "cloudUserId": cloudUserId as Any,
                "notification": notification as Any
            ]
        )
    }
}

extension UNUserNotificationCenter: @retroactive @unchecked Sendable {}
extension UNNotificationResponse: @retroactive @unchecked Sendable {}
extension UNNotification: @retroactive @unchecked Sendable {}
