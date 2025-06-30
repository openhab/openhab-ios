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

import Combine
import OpenHABCore
import SideMenu
import SwiftMessages
import UIKit

protocol OpenHABViewable: AnyObject {
    func reloadView()
    func viewName() -> String
    func pushSitemap(name: String, path: String?) async
}

class OpenHABViewController: UIViewController, OpenHABViewable {
    var trackerCancellables = Set<AnyCancellable>()

    var activeTasks = Set<Task<Void, Never>>()

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.didBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NetworkTracker.shared.clientCertificateManager.delegate = self
        NetworkTracker.shared.serverCertificateManager.delegate = self
    }

    func showPopupMessage(seconds: Double, title: String, message: String, theme: Theme) {
        var config = SwiftMessages.Config()
        config.duration = .seconds(seconds: seconds)
        config.presentationStyle = .bottom
        SwiftMessages.hideAll()
        SwiftMessages.show(config: config) {
            let view = MessageView.viewFromNib(layout: .cardView)
            // ... configure the view
            view.configureTheme(theme)
            view.configureContent(title: title, body: message)
            view.button?.setTitle(NSLocalizedString("dismiss", comment: ""), for: .normal)
            view.buttonTapHandler = { _ in SwiftMessages.hide() }
            return view
        }
    }

    func hidePopupMessages() {
        SwiftMessages.hideAll()
    }

    func showSideMenu() {
        if let rc = parent as? OpenHABRootViewController {
            rc.showSideMenu()
        }
    }

    @objc
    func didEnterBackground(_ notification: Notification?) {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    @objc
    func didBecomeActive(_ notification: Notification?) {
        // re disable idle off timer
        if Preferences.idleOff {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    // To be overridden by sub classes

    func reloadView() {}

    func viewName() -> String {
        "default"
    }

    func pushSitemap(name: String, path: String?) async {
        // No-op for non-sitemap view controllers
    }
}

// MARK: - ServerCertificateManagerDelegate

extension OpenHABViewController: ServerCertificateManagerDelegate {
    // delegate should ask user for a decision on what to do with invalid certificate
    @MainActor
    func evaluateServerTrust(summary certificateSummary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult {
        await withCheckedContinuation { continuation in
            let title = NSLocalizedString("ssl_certificate_warning", comment: "")
            let message = String(format: NSLocalizedString("ssl_certificate_invalid", comment: ""), certificateSummary ?? "", domain ?? "")
            let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

            alertView.addAction(UIAlertAction(title: NSLocalizedString("abort", comment: ""), style: .default) { _ in
                continuation.resume(returning: .deny)
            })
            alertView.addAction(UIAlertAction(title: NSLocalizedString("once", comment: ""), style: .default) { _ in
                continuation.resume(returning: .permitOnce)
            })
            alertView.addAction(UIAlertAction(title: NSLocalizedString("always", comment: ""), style: .default) { _ in
                continuation.resume(returning: .permitAlways)
            })

            self.present(alertView, animated: true, completion: nil)
        }
    }

    // certificate received from openHAB doesn't match our record, ask user for a decision
    @MainActor
    func evaluateCertificateMismatch(summary certificateSummary: String?, forDomain domain: String?) async -> OpenHABCore.ServerCertificateManager.EvaluateResult {
        await withCheckedContinuation { continuation in
            let title = NSLocalizedString("ssl_certificate_warning", comment: "")
            let message = String(format: NSLocalizedString("ssl_certificate_no_match", comment: ""), certificateSummary ?? "", domain ?? "")
            let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

            alertView.addAction(UIAlertAction(title: NSLocalizedString("abort", comment: ""), style: .default) { _ in
                continuation.resume(returning: .deny)
            })
            alertView.addAction(UIAlertAction(title: NSLocalizedString("once", comment: ""), style: .default) { _ in
                continuation.resume(returning: .permitOnce)
            })
            alertView.addAction(UIAlertAction(title: NSLocalizedString("always", comment: ""), style: .default) { _ in
                continuation.resume(returning: .permitAlways)
            })

            self.present(alertView, animated: true, completion: nil)
        }
    }

    @MainActor
    func acceptedServerCertificatesChanged() {
        // User's decision about trusting server certificates has changed.  Send updates to the paired watch.
        WatchMessageService.singleton.syncPreferencesToWatch()
    }
}

// MARK: - ClientCertificateManagerDelegate

@MainActor
extension OpenHABViewController: ClientCertificateManagerDelegate {
    // Ask user whether to import the certificate
    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?) async -> Bool {
        let shouldImport = await withCheckedContinuation { continuation in
            let alertController = UIAlertController(
                title: NSLocalizedString("certificate_import_title", comment: ""),
                message: NSLocalizedString("certificate_import_text", comment: ""),
                preferredStyle: .alert
            )

            let okay = UIAlertAction(title: NSLocalizedString("okay", comment: ""), style: .default) { _ in
                continuation.resume(returning: true)
            }

            let cancel = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { _ in
                continuation.resume(returning: false)
            }

            alertController.addAction(okay)
            alertController.addAction(cancel)

            self.present(alertController, animated: true)
        }
        if shouldImport {
            await clientCertificateManager!.clientCertificateAccepted(password: nil)
            return true
        } else {
            clientCertificateManager!.clientCertificateRejected()
            return false
        }
    }

    // Ask user for password to decode PKCS#12
    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?) async -> String? {
        await withCheckedContinuation { continuation in
            let alertController = UIAlertController(
                title: NSLocalizedString("certificate_import_title", comment: ""),
                message: NSLocalizedString("certificate_import_password", comment: ""),
                preferredStyle: .alert
            )

            alertController.addTextField { textField in
                textField.placeholder = NSLocalizedString("password", comment: "")
                textField.isSecureTextEntry = true
            }

            let okay = UIAlertAction(title: NSLocalizedString("okay", comment: ""), style: .default) { _ in
                let password = alertController.textFields?.first?.text
                continuation.resume(returning: password)
            }

            let cancel = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { _ in
                continuation.resume(returning: nil)
            }

            alertController.addAction(okay)
            alertController.addAction(cancel)

            self.present(alertController, animated: true)
        }
    }

    // Show alert if certificate import failed
    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String) async {
        let alertController = UIAlertController(
            title: NSLocalizedString("certificate_import_title", comment: ""),
            message: errMsg,
            preferredStyle: .alert
        )

        let okay = UIAlertAction(title: NSLocalizedString("okay", comment: ""), style: .default)
        alertController.addAction(okay)

        present(alertController, animated: true)
    }
}
