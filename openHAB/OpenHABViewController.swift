// Copyright (c) 2010-2022 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import DynamicButton
import OpenHABCore
import SideMenu
import SwiftMessages
import UIKit

class OpenHABViewController: UIViewController {
    var hamburgerButton: DynamicButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let hamburgerButtonItem: UIBarButtonItem
        if #available(iOS 13.0, *) {
            let imageConfig = UIImage.SymbolConfiguration(textStyle: .largeTitle)
            let buttonImage = UIImage(systemName: "line.horizontal.3", withConfiguration: imageConfig)
            let button = UIButton(type: .custom)
            button.setImage(buttonImage, for: .normal)
            button.addTarget(self, action: #selector(OpenHABWebViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
            hamburgerButtonItem = UIBarButtonItem(customView: button)
            hamburgerButtonItem.customView?.heightAnchor.constraint(equalToConstant: 30).isActive = true
        } else {
            hamburgerButton = DynamicButton(frame: CGRect(x: 0, y: 0, width: 31, height: 31))
            hamburgerButton.setStyle(.hamburger, animated: true)
            hamburgerButton.addTarget(self, action: #selector(OpenHABWebViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
            hamburgerButton.strokeColor = view.tintColor
            hamburgerButtonItem = UIBarButtonItem(customView: hamburgerButton)
        }
        navigationItem.setRightBarButton(hamburgerButtonItem, animated: true)
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NetworkConnection.shared.assignDelegates(serverDelegate: self, clientDelegate: self)
    }
    
    @objc
    func rightDrawerButtonPress(_ sender: Any?) {
        guard let menu = SideMenuManager.default.rightMenuNavigationController else { return }
        present(menu, animated: true)
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
            view.configureContent(title: NSLocalizedString(title, comment: ""), body: message)
            view.button?.setTitle(NSLocalizedString("dismiss", comment: ""), for: .normal)
            view.buttonTapHandler = { _ in SwiftMessages.hide() }
            return view
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
    func evaluateServerTrust(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?) {
        DispatchQueue.main.async {
            let title = NSLocalizedString("ssl_certificate_warning", comment: "")
            let message = String(format: NSLocalizedString("ssl_certificate_invalid", comment: ""), certificateSummary ?? "", domain ?? "")
            let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: NSLocalizedString("abort", comment: ""), style: .default) { _ in policy?.evaluateResult = .deny })
            alertView.addAction(UIAlertAction(title: NSLocalizedString("once", comment: ""), style: .default) { _ in policy?.evaluateResult = .permitOnce })
            alertView.addAction(UIAlertAction(title: NSLocalizedString("always", comment: ""), style: .default) { _ in policy?.evaluateResult = .permitAlways })
            self.present(alertView, animated: true) {}
        }
    }
    
    // certificate received from openHAB doesn't match our record, ask user for a decision
    func evaluateCertificateMismatch(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?) {
        DispatchQueue.main.async {
            let title = NSLocalizedString("ssl_certificate_warning", comment: "")
            let message = String(format: NSLocalizedString("ssl_certificate_no_match", comment: ""), certificateSummary ?? "", domain ?? "")
            let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: NSLocalizedString("abort", comment: ""), style: .default) { _ in policy?.evaluateResult = .deny })
            alertView.addAction(UIAlertAction(title: NSLocalizedString("once", comment: ""), style: .default) { _ in policy?.evaluateResult = .permitOnce })
            alertView.addAction(UIAlertAction(title: NSLocalizedString("always", comment: ""), style: .default) { _ in policy?.evaluateResult = .permitAlways })
            self.present(alertView, animated: true) {}
        }
    }
    
    func acceptedServerCertificatesChanged(_ policy: ServerCertificateManager?) {
        // User's decision about trusting server certificates has changed.  Send updates to the paired watch.
        WatchMessageService.singleton.syncPreferencesToWatch()
    }
}

// MARK: - ClientCertificateManagerDelegate

extension OpenHABViewController: ClientCertificateManagerDelegate {
    // delegate should ask user for a decision on whether to import the client certificate into the keychain
    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: NSLocalizedString("certificate_import_title", comment: ""), message: NSLocalizedString("certificate_import_text", comment: ""), preferredStyle: .alert)
            let okay = UIAlertAction(title: NSLocalizedString("okay", comment: ""), style: .default) { (_: UIAlertAction) in
                clientCertificateManager!.clientCertificateAccepted(password: nil)
            }
            let cancel = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { (_: UIAlertAction) in
                clientCertificateManager!.clientCertificateRejected()
            }
            alertController.addAction(okay)
            alertController.addAction(cancel)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    // delegate should ask user for the export password used to decode the PKCS#12
    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: NSLocalizedString("certificate_import_title", comment: ""), message: NSLocalizedString("certificate_import_password", comment: ""), preferredStyle: .alert)
            let okay = UIAlertAction(title: NSLocalizedString("okay", comment: ""), style: .default) { (_: UIAlertAction) in
                let txtField = alertController.textFields?.first
                let password = txtField?.text
                clientCertificateManager!.clientCertificateAccepted(password: password)
            }
            let cancel = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { (_: UIAlertAction) in
                clientCertificateManager!.clientCertificateRejected()
            }
            alertController.addTextField { textField in
                textField.placeholder = NSLocalizedString("password", comment: "")
                textField.isSecureTextEntry = true
            }
            alertController.addAction(okay)
            alertController.addAction(cancel)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    // delegate should alert the user that an error occured importing the certificate
    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: NSLocalizedString("certificate_import_title", comment: ""), message: errMsg, preferredStyle: .alert)
            let okay = UIAlertAction(title: NSLocalizedString("okay", comment: ""), style: .default)
            alertController.addAction(okay)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}
