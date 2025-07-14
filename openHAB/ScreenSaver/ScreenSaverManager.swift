// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import os.log
import UIKit

private class ScreenSaverHostingViewController: UIViewController {
    override var prefersStatusBarHidden: Bool { true }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
}

@MainActor
final class ScreenSaverManager: NSObject {
    static let shared = ScreenSaverManager()

    private let logger = Logger(subsystem: "org.openhab", category: "ScreenSaver")

    private(set) var configuration = ScreenSaverConfiguration()

    private var idleTimer: Timer?

    /// The window we are observing / presenting the saver on.
    private weak var window: UIWindow?

    /// The currently visible screen saver (if any).
    private var saverView: ScreenSaverView?

    /// Separate window sitting above the status bar to ensure the saver covers
    /// the entire screen, including the system status bar.
    private var overlayWindow: UIWindow?

    /// Remembers the screen brightness before the dimming is applied
    private var previousBrightness: CGFloat?

    override private init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleDisableNotification), name: .disableScreenSaver, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleWakeNotification), name: .wakeScreenSaver, object: nil)
    }

    func startMonitoring(window: UIWindow, configuration: ScreenSaverConfiguration = ScreenSaverConfiguration()) {
        self.configuration = configuration
        self.window = window
        attachGestureRecognizers(to: window)
        resetIdleTimer()
    }

    public func updateConfiguration(_ newConfiguration: ScreenSaverConfiguration) {
        configuration = newConfiguration
        if saverView != nil {
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
        guard saverView == nil, let baseWindow = window else { return }
        logger.debug("Presenting screen saver (overlay window)")

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

        // Trigger status bar update
        hostVC.setNeedsStatusBarAppearanceUpdate()

        let saver = ScreenSaverView(configuration: configuration)
        saver.translatesAutoresizingMaskIntoConstraints = false
        hostVC.view.addSubview(saver)
        NSLayoutConstraint.activate([
            saver.leadingAnchor.constraint(equalTo: hostVC.view.leadingAnchor),
            saver.trailingAnchor.constraint(equalTo: hostVC.view.trailingAnchor),
            saver.topAnchor.constraint(equalTo: hostVC.view.topAnchor),
            saver.bottomAnchor.constraint(equalTo: hostVC.view.bottomAnchor)
        ])

        // wake up if the user taps anywhere
        attachGestureRecognizers(to: overlay)

        saver.alpha = 0
        UIView.animate(withDuration: 0.3) {
            saver.alpha = 1.0
        } completion: { _ in
            saver.startAnimation()
        }

        saverView = saver
        overlayWindow = overlay
        applyDimming()
    }

    private func dismissSaverIfNeeded() {
        guard let saver = saverView else { return }
        logger.debug("Dismissing screen saver")
        saver.stopAnimation()
        if configuration.enablesAutoDimming {
            if configuration.restoresBrightness {
                restoreBrightnessIfNeeded()
            } else {
                let target = min(max(configuration.wakeBrightnessLevel, 0.0), 1.0)
                UIScreen.main.brightness = target
            }
        }
        UIView.animate(withDuration: 0.2, animations: {
            saver.alpha = 0
        }) { _ in
            saver.removeFromSuperview()
        }
        saverView = nil

        // Tear down overlay window
        overlayWindow?.isHidden = true
        overlayWindow = nil
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

    /// Immediately presents the screen saver with the provided configuration, ignoring the idle timer.
    /// This is used fo testing the screen saver in the Settings view (before settings are saved)
    @MainActor
    func presentSaver(configuration: ScreenSaverConfiguration) {
        self.configuration = configuration
        dismissSaverIfNeeded()
        showSaver()
    }

    @objc private func handleDisableNotification() {
        logger.debug("Received disable screen saver notification")
        idleTimer?.invalidate()
        dismissSaverIfNeeded()
    }

    @objc private func handleWakeNotification() {
        logger.debug("Received wake screen saver notification")
        resetIdleTimer()
        dismissSaverIfNeeded()
    }
}

/// Notifications that other parts of the app can send to control the screensaver
extension Notification.Name {
    static let disableScreenSaver = Notification.Name("disableScreenSaver")
    static let wakeScreenSaver = Notification.Name("wakeScreenSaver")
}

extension ScreenSaverManager: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our gesture recognizers to live side-by-side with the app's recognizers.
        true
    }
}
