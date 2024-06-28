// Copyright (c) 2010-2024 Contributors to the openHAB project
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
import StoreKit
import UIKit

class LegacyNoticeViewController: UIViewController, SKStoreProductViewControllerDelegate {
    @IBOutlet private var toggleSwitch: UISwitch!
    @IBOutlet private var textView: UITextView!

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        toggleSwitch.isOn = !Preferences.promptForUpgrade
        textView.text = NSLocalizedString("upgrade_message_body", comment: "Click below to update")
    }

    @IBAction func imageClicked(_ sender: Any) {
        if let updatedAppId = appData?.updatedAppId, !updatedAppId.isEmpty {
            openStoreProductWithiTunesItemIdentifier(appData!.updatedAppId)
        }
    }

    @IBAction func switchValueChanged(_ sender: UISwitch) {
        Preferences.promptForUpgrade = !sender.isOn
    }

    func openStoreProductWithiTunesItemIdentifier(_ identifier: String) {
        let storeViewController = SKStoreProductViewController()
        storeViewController.delegate = self

        let parameters = [SKStoreProductParameterITunesItemIdentifier: identifier]
        storeViewController.loadProduct(withParameters: parameters) { [weak self] (loaded, _) in
            if loaded {
                self?.present(storeViewController, animated: true, completion: nil)
            }
        }
    }

    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss(animated: true, completion: nil)
    }
}
