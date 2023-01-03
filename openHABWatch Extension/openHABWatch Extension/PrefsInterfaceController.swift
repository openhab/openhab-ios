// Copyright (c) 2010-2023 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Foundation
import WatchKit

class PrefsInterfaceController: WKInterfaceController {
    @IBOutlet private var versionLabel: WKInterfaceLabel!
    @IBOutlet private var localUrlLabel: WKInterfaceLabel!
    @IBOutlet private var remoteUrlLabel: WKInterfaceLabel!
    @IBOutlet private var usernameLabel: WKInterfaceLabel!
    @IBOutlet private var sitemapLabel: WKInterfaceLabel!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        displayTheApplicationVersionNumber()

        localUrlLabel.setText(Preferences.localUrl)
        remoteUrlLabel.setText(Preferences.remoteUrl)
        sitemapLabel.setText(Preferences.sitemapName)
        usernameLabel.setText(Preferences.username)
    }

    func displayTheApplicationVersionNumber() {
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        versionLabel.setText("V\(versionNumber).\(buildNumber)")
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
}
