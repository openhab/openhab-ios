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
import SwiftUI
import UIKit

private class ScreenSaverHostingViewController: UIViewController {
    override var prefersStatusBarHidden: Bool {
        true
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .fade
    }
}

@MainActor
final class ScreenSaverManager: NSObject {
    static let shared = ScreenSaverManager()

    private(set) var configuration = ScreenSaverConfiguration()

    private var idleTimer: Timer?

    private weak var window: UIWindow?

    private var overlayWindow: UIWindow?

    private var previousBrightness: CGFloat?

    override private init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleDisableNotification), name: .disableScreenSaver, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleWakeNotification), name: .wakeScreenSaver, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleActivateNotification), name: .activateScreenSaver, object: nil)
    }

    func startMonitoring(window: UIWindow, configuration: ScreenSaverConfiguration = ScreenSaverConfiguration()) {
        self.configuration = configuration
        self.window = window
        attachGestureRecognizers(to: window)
        resetIdleTimer()
    }

    func updateConfiguration(_ newConfiguration: ScreenSaverConfiguration) {
        configuration = newConfiguration
        if overlayWindow != nil {
            dismissSaverIfNeeded()
        }

        if configuration.isEnabled {
            resetIdleTimer()
        }
    }

    private func attachGestureRecognizers(to window: UIWindow) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(userInteracted))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesEnded = false
        tap.delegate = self
        window.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(userInteracted))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        window.addGestureRecognizer(pan)
    }

    @objc private func userInteracted() {
        dismissSaverIfNeeded()
        resetIdleTimer()
    }

    private func resetIdleTimer() {
        idleTimer?.invalidate()

        idleTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.idleInterval,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }

            Task { @MainActor in
                self.showSaver()
            }
        }
    }

    private func showSaver() {
        guard configuration.isEnabled else { return }
        guard overlayWindow == nil, let baseWindow = window else { return }
        Logger.screenSaver.debug("Presenting screen saver (overlay window)")

        let overlay: UIWindow
        if let scene = baseWindow.windowScene {
            overlay = UIWindow(windowScene: scene)
            overlay.frame = scene.coordinateSpace.bounds
        } else {
            overlay = UIWindow(frame: UIScreen.main.bounds)
        }
        overlay.windowLevel = .alert + 1 // ensure above status bar
        overlay.backgroundColor = .clear

        let hostVC = ScreenSaverHostingViewController()
        hostVC.view.backgroundColor = .clear
        overlay.rootViewController = hostVC
        overlay.makeKeyAndVisible()

        hostVC.setNeedsStatusBarAppearanceUpdate()

        let swiftUIView = ScreenSaverView(configuration: configuration)
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        hostVC.addChild(hostingController)
        hostVC.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: hostVC)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: hostVC.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: hostVC.view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: hostVC.view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: hostVC.view.bottomAnchor)
        ])

        hostingController.view.alpha = 0
        UIView.animate(withDuration: 0.3) {
            hostingController.view.alpha = 1.0
        }

        overlayWindow = overlay
        applyDimming()
    }

    private func dismissSaverIfNeeded() {
        guard overlayWindow != nil else { return }
        Logger.screenSaver.debug("Dismissing screen saver")
        if configuration.enablesAutoDimming {
            if configuration.restoresBrightness {
                restoreBrightnessIfNeeded()
            } else {
                let target = min(max(configuration.wakeBrightnessLevel, 0.0), 1.0)
                UIScreen.main.brightness = target
            }
        }
        // Animate dismissal for the overlay window
        UIView.animate(withDuration: 0.2) {
            self.overlayWindow?.alpha = 0
        } completion: { _ in
            // Clean up overlay window
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
        }
    }

    private func applyDimming() {
        guard configuration.enablesAutoDimming else { return }
        previousBrightness = UIScreen.main.brightness
        var target = configuration.dimLevel
        target = min(max(target, 0.0), 1.0)
        UIScreen.main.brightness = target
    }

    private func restoreBrightnessIfNeeded() {
        guard let original = previousBrightness else { return }
        UIScreen.main.brightness = original
        previousBrightness = nil
    }

    /// This is used fo testing the screen saver in the Settings view (before settings are saved)
    @MainActor
    func presentSaver(configuration: ScreenSaverConfiguration) {
        self.configuration = configuration
        dismissSaverIfNeeded()
        showSaver()
    }

    @objc private func handleDisableNotification() {
        Logger.screenSaver.debug("Received disable screen saver notification")
        idleTimer?.invalidate()
        dismissSaverIfNeeded()
    }

    @objc private func handleWakeNotification() {
        Logger.screenSaver.debug("Received wake screen saver notification")
        resetIdleTimer()
        dismissSaverIfNeeded()
    }

    @objc private func handleActivateNotification() {
        Logger.screenSaver.debug("Received activate screen saver notification")
        dismissSaverIfNeeded()
        showSaver()
    }
}

/// Notifications that other parts of the app can send to control the screensaver
extension Notification.Name {
    static let disableScreenSaver = Notification.Name("disableScreenSaver")
    static let wakeScreenSaver = Notification.Name("wakeScreenSaver")
    static let activateScreenSaver = Notification.Name("activateScreenSaver")
}

extension ScreenSaverManager: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
