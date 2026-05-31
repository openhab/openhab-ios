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

import OpenHABCore
import os.log
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // The window is created automatically from UISceneStoryboardFile in the scene configuration.
        // Handle any URLs that caused the app to be launched.
        if !connectionOptions.urlContexts.isEmpty {
            handleURLContexts(connectionOptions.urlContexts)
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        NotificationCenter.default.post(name: .disableScreenSaver, object: nil)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let window else { return }
        var config = ScreenSaverConfiguration()
        config.isEnabled = Preferences.shared.screensaverEnabled
        config.showsTime = Preferences.shared.screensaverShowsTime
        config.showsDate = Preferences.shared.screensaverShowsDate
        config.idleInterval = Preferences.shared.screensaverIdleInterval
        config.movementInterval = Preferences.shared.screensaverMovementInterval
        config.fontName = Preferences.shared.screensaverFontName.isEmpty ? nil : Preferences.shared.screensaverFontName
        config.timeFontSizeRatio = CGFloat(Preferences.shared.screensaverTimeFontRatio)
        config.dateFontRelativeSize = CGFloat(Preferences.shared.screensaverDateFontRatio)
        config.enablesAutoDimming = Preferences.shared.screensaverEnableDimming
        config.dimLevel = CGFloat(Preferences.shared.screensaverDimLevel)
        config.wakeBrightnessLevel = CGFloat(Preferences.shared.screensaverWakeBrightness)
        config.showsSeconds = Preferences.shared.screensaverShowsSeconds
        config.uses24HourTime = Preferences.shared.screensaverUse24Hour
        config.restoresBrightness = Preferences.shared.screensaverRestoreBrightness
        ScreenSaverManager.shared.startMonitoring(window: window, configuration: config)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {}

    func sceneWillEnterForeground(_ scene: UIScene) {}

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handleURLContexts(URLContexts)
    }

    private func handleURLContexts(_ contexts: Set<UIOpenURLContext>) {
        for context in contexts {
            handle(context: context)
        }
    }

    private func handle(context: UIOpenURLContext) {
        let url = context.url
        Logger.appDelegate.info("Calling Application Bundle ID: \(context.options.sourceApplication ?? "")")
        Logger.appDelegate.info("URL: \(url.absoluteString)")
        Logger.appDelegate.info("URL scheme: \(url.scheme ?? "")")
        Logger.appDelegate.info("URL query: \(url.query ?? "")")

        if url.isFileURL {
            Logger.appDelegate.info("Loading Certificate")
            let clientCertificateManager = CertificateManagers.clientCertificateManager
            Task { @MainActor in
                await clientCertificateManager.startImportClientCertificate(url: url)
            }
            return
        }

        // Remove the 'openhab' scheme prefix from the URL
        let action = url.absoluteString.split(separator: ":").dropFirst().joined(separator: ":")
        Task { @MainActor in
            AppDelegate.appDelegate.notificationDelegate.notifyNotificationListeners(action: action)
        }
    }
}
