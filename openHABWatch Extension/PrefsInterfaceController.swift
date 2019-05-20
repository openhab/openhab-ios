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

    @IBOutlet weak var versionLabel: WKInterfaceLabel!
    @IBOutlet weak var localUrlLabel: WKInterfaceLabel!
    @IBOutlet weak var remoteUrlLabel: WKInterfaceLabel!
    @IBOutlet weak var usernameLabel: WKInterfaceLabel!
    @IBOutlet weak var sitemapLabel: WKInterfaceLabel!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        displayTheApplicationVersionNumber()

        localUrlLabel.setText(UserDefaultsRepository.readLocalUrl())
        remoteUrlLabel.setText(UserDefaultsRepository.readRemoteUrl())

        sitemapLabel.setText(UserDefaultsRepository.readSitemapName())

        usernameLabel.setText(UserDefaultsRepository.readUsername())
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
