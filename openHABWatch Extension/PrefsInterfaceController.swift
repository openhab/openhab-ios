//
//  InterfaceController.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 01.05.18.
//  Copyright © 2018 private. All rights reserved.
//

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
