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

import AudioToolbox
import Combine
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

/// Plays the in-app notification ping using AudioServicesPlaySystemSound, which routes
/// through the system sound path and natively respects the ringer/silent switch without
/// touching the shared AVAudioSession. This avoids the .playback-vs-.ambient category
/// race that affected concurrent video-widget audio.
@MainActor
final class AudioPlayerActor {
    private var soundID: SystemSoundID = 0

    init() {
        if let url = Bundle.main.url(forResource: "ping", withExtension: "wav") {
            AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        }
    }

    deinit {
        if soundID != 0 {
            AudioServicesDisposeSystemSoundID(soundID)
        }
    }

    func playSound() {
        guard soundID != 0 else { return }
        AudioServicesPlaySystemSound(soundID)
    }

    func stopSound() {
        // System sounds cannot be stopped mid-play; the ping is short enough that this is fine.
    }
}

@MainActor
final class NotificationCenterDelegateImpl: NSObject, UNUserNotificationCenterDelegate {
    let audioPlayer = AudioPlayerActor()

    /// this is called when a notification comes in while in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        Logger.notificationCenterDelegateImpl.info("Notification received while app is in foreground: \(userInfo)")

        let payload = PushNotificationPayload(userInfo: userInfo)

        NotificationCenter.default.post(
            name: .openHABDidReceiveNotification,
            object: payload,
            userInfo: userInfo
        )

        guard !payload.isHideNotification else {
            return []
        }

        // Use the system banner when there are media attachments so the image is visible.
        // The didReceive handler will process any on-click action when the user taps.
        if !notification.request.content.attachments.isEmpty {
            return [.banner, .sound]
        }

        await displayNotification(payload: payload)

        return []
    }

    // this is called when clicking a notification while in the background
    // swiftlint:disable:next async_without_await
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

    private func displayNotification(payload: PushNotificationPayload) async {
        Logger.notificationCenterDelegateImpl.info("displayNotification \(payload.message ?? "")")

        audioPlayer.playSound()

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
        if let activeConnection = MainActorNetworkTracker.shared.activeConnection,
           let url = Endpoint.icon(rootUrl: activeConnection.configuration.url, version: activeConnection.version, icon: payload.icon, state: nil, iconType: .svg, iconColor: "", staticIcon: false)?.url {
            do {
                let fetcher = OpenHABImageFetcher()
                iconImage = try await fetcher.image(
                    from: url,
                    targetSize: CGSize(width: 24, height: 24),
                    extraOptions: [.requestModifier(OpenHABAccessTokenAdapter(connectionConfiguration: activeConnection.configuration))]
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
                    title: String(localized: "notification", comment: ""),
                    body: payload.displayMessage,
                    iconImage: iconImage
                )
                view.button?.setTitle(String(localized: "dismiss", comment: ""), for: .normal)
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
    // swiftlint:disable:next async_without_await
    func messageViewTapped(action: String?, cloudUserId: String? = nil) async {
        notifyNotificationListeners(action: action, cloudUserId: cloudUserId)
        SwiftMessages.hideAll()
    }

    /// ✅ Ensure this runs on the MainActor
    @MainActor
    func notifyNotificationListeners(action: String?, cloudUserId: String? = nil, notification: UNNotification? = nil) {
        // Wake up screen saver immediately on incoming notification interaction
        NotificationCenter.default.post(name: .wakeScreenSaver, object: nil)

        // Search all windows across all scenes: key-window lookup fails when SwiftMessages owns
        // the key window (foreground) or the scene is still transitioning (background tap).
        let rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .compactMap { $0.rootViewController as? UINavigationController }
            .compactMap { $0.viewControllers.first as? OpenHABRootViewController }
            .first
        rootViewController?.handleNotification(action: action, cloudUserId: cloudUserId, notification: notification)
    }
}

extension UNUserNotificationCenter: @retroactive @unchecked Sendable {}
extension UNNotificationResponse: @retroactive @unchecked Sendable {}
extension UNNotification: @retroactive @unchecked Sendable {}
