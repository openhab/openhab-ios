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
import SFSafeSymbols
import SwiftMessages
import UIKit
@preconcurrency import UserNotifications
import WatchConnectivity

@MainActor
struct OpenHABImageFetcher {
    private let logger = Logger(subsystem: "org.openhab", category: "ImageFetcher")

    func image(from url: URL,
               targetSize: CGSize? = nil,
               extraOptions: KingfisherOptionsInfo = []) async throws -> UIImage {
        let processor = OpenHABImageProcessor()

        var options: KingfisherOptionsInfo = [
            .processor(processor)
        ]

        options.append(contentsOf: extraOptions)

        let result = try await KingfisherManager.shared.retrieveImage(with: url, options: options)

        logger.debug("Fetched image \(result.image.size.debugDescription, privacy: .public) from \(url.absoluteString, privacy: .public)")
        return result.image
    }
}

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

        let payload = PushNotificationPayload(userInfo: userInfo)

        NotificationCenter.default.post(
            name: .openHABDidReceiveNotification,
            object: payload,
            userInfo: userInfo
        )

        await displayNotification(payload: payload)

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

    private func displayNotification(payload: PushNotificationPayload) async {
        Logger.notificationCenterDelegateImpl.info("displayNotification \(payload.message ?? "")")

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

        var iconImage = UIImage(systemSymbol: .exclamationmark)
        if let rootUrl = MainActorNetworkTracker.shared.activeConnection?.configuration.url,
           let url = Endpoint.icon(rootUrl: rootUrl, version: 2, icon: payload.icon, state: nil, iconType: .svg, iconColor: "", staticIcon: false)?.url {
            do {
                let fetcher = OpenHABImageFetcher()
                iconImage = try await fetcher.image(
                    from: url,
                    targetSize: CGSize(width: 24, height: 24)
                )
            } catch {
                Logger.notificationCenterDelegateImpl.error("Image load failed: \(error)")
            }
        }

        await MainActor.run {
            SwiftMessages.show(config: config) {
                let view = MessageView.viewFromNib(layout: .cardView)
                view.configureTheme(.info)
                view.configureContent(
                    title: NSLocalizedString("notification", comment: ""),
                    body: payload.message.orEmpty,
                    iconImage: iconImage
                )
                view.button?.setTitle(NSLocalizedString("dismiss", comment: ""), for: .normal)
                view.configureIcon(withSize: CGSize(width: 24, height: 24), contentMode: .scaleAspectFit)
                view.buttonTapHandler = { _ in SwiftMessages.hide() }

                // Use closure-based tap gesture instead of #selector
                let tapGesture = MessageTapGestureRecognizer {
                    Task {
                        await self.messageViewTapped(action: payload.action, cloudUserId: payload.cloudUserId)
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
