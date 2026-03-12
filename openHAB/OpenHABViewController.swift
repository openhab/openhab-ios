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

import Combine
import OpenHABCore
import SideMenu
import SwiftMessages
import UIKit

@MainActor
protocol OpenHABViewable: AnyObject {
    func reloadView()
    func viewName() -> String
    // swiftlint:disable:next  function_parameter_count
    func showPopupMessage(seconds: Double,
                          title: String,
                          message: String,
                          theme: Theme,
                          viewTapAction: (() -> Void)?,
                          buttonTitle: String,
                          buttonAction: (() -> Void)?)
    func hidePopupMessages()
}

class OpenHABViewController: UIViewController, OpenHABViewable {
    var trackerCancellables = Set<AnyCancellable>()

    var activeTasks = Set<Task<Void, Never>>()

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.didBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        CertificateManagers.clientCertificateManager.delegate = self
        CertificateManagers.serverCertificateManager.delegate = self
    }

    func showPopupMessage(seconds: Double,
                          title: String,
                          message: String,
                          theme: Theme,
                          viewTapAction: (() -> Void)? = nil,
                          buttonTitle: String = String(localized: "dismiss", comment: ""),
                          buttonAction: (() -> Void)? = nil) {
        var config = SwiftMessages.Config()
        if seconds >= 0 {
            config.duration = .seconds(seconds: seconds)
        } else {
            config.duration = .forever
        }
        config.presentationStyle = .bottom
        config.presentationContext = .view(view)
        SwiftMessages.hideAll()
        SwiftMessages.show(config: config) {
            let view = MessageView.viewFromNib(layout: .cardView)
            // ... configure the view
            view.configureTheme(theme)
            view.configureContent(title: title, body: message)
            view.button?.setTitle(buttonTitle, for: .normal)
            view.buttonTapHandler = { _ in
                SwiftMessages.hide()
                buttonAction?()
            }
            view.tapHandler = { _ in
                viewTapAction?()
            }
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
        if Preferences.shared.idleOff {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    // To be overridden by sub classes

    func reloadView() {}

    func viewName() -> String {
        "default"
    }
}

// MARK: - ServerCertificateManagerDelegate

extension OpenHABViewController: ServerCertificateManagerDelegate {
    // delegate should ask user for a decision on what to do with invalid certificate
    @MainActor
    func evaluateServerTrust(summary certificateSummary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult {
        await withCheckedContinuation { continuation in
            let title = String(localized: "ssl_certificate_warning", comment: "")
            let message = String(format: String(localized: "ssl_certificate_invalid", comment: ""), certificateSummary ?? "", domain ?? "")
            let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

            alertView.addAction(UIAlertAction(title: String(localized: "Cancel", comment: ""), style: .default) { _ in
                continuation.resume(returning: .deny)
            })
            alertView.addAction(UIAlertAction(title: String(localized: "Once", comment: ""), style: .default) { _ in
                continuation.resume(returning: .permitOnce)
            })
            alertView.addAction(UIAlertAction(title: String(localized: "Always", comment: ""), style: .default) { _ in
                continuation.resume(returning: .permitAlways)
            })

            self.present(alertView, animated: true, completion: nil)
        }
    }

    // certificate received from openHAB doesn't match our record, ask user for a decision
    @MainActor
    func evaluateCertificateMismatch(summary certificateSummary: String?, forDomain domain: String?) async -> OpenHABCore.ServerCertificateManager.EvaluateResult {
        await withCheckedContinuation { continuation in
            let title = String(localized: "ssl_certificate_warning", comment: "")
            let message = String(format: String(localized: "ssl_certificate_no_match", comment: ""), certificateSummary ?? "", domain ?? "")
            let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

            alertView.addAction(UIAlertAction(title: String(localized: "Cancel", comment: ""), style: .default) { _ in
                continuation.resume(returning: .deny)
            })
            alertView.addAction(UIAlertAction(title: String(localized: "Once", comment: ""), style: .default) { _ in
                continuation.resume(returning: .permitOnce)
            })
            alertView.addAction(UIAlertAction(title: String(localized: "Always", comment: ""), style: .default) { _ in
                continuation.resume(returning: .permitAlways)
            })

            self.present(alertView, animated: true, completion: nil)
        }
    }

    @MainActor
    func acceptedServerCertificatesChanged() {
        // User's decision about trusting server certificates has changed.  Send updates to the paired watch.
        Task {
            await WatchMessageService.singleton.syncPreferencesToWatch()
        }
    }
}

// MARK: - ClientCertificateManagerDelegate

@MainActor
extension OpenHABViewController: ClientCertificateManagerDelegate {
    // Ask user whether to import the certificate
    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?) async -> Bool {
        let shouldImport = await withCheckedContinuation { continuation in
            let alertController = UIAlertController(
                title: String(localized: "certificate_import_title", comment: ""),
                message: String(localized: "certificate_import_text", comment: ""),
                preferredStyle: .alert
            )

            let okay = UIAlertAction(title: String(localized: "okay", comment: ""), style: .default) { _ in
                continuation.resume(returning: true)
            }

            let cancel = UIAlertAction(title: String(localized: "cancel", comment: ""), style: .cancel) { _ in
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
                title: String(localized: "certificate_import_title", comment: ""),
                message: String(localized: "certificate_import_password", comment: ""),
                preferredStyle: .alert
            )

            alertController.addTextField { textField in
                textField.placeholder = String(localized: "password", comment: "")
                textField.isSecureTextEntry = true
            }

            let okay = UIAlertAction(title: String(localized: "okay", comment: ""), style: .default) { _ in
                let password = alertController.textFields?.first?.text
                continuation.resume(returning: password)
            }

            let cancel = UIAlertAction(title: String(localized: "cancel", comment: ""), style: .cancel) { _ in
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
            title: String(localized: "certificate_import_title", comment: ""),
            message: errMsg,
            preferredStyle: .alert
        )

        let okay = UIAlertAction(title: String(localized: "okay", comment: ""), style: .default)
        alertController.addAction(okay)

        present(alertController, animated: true)
    }
}
