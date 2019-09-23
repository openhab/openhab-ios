//
//  OpenHABInfoViewController.swift
//  openHAB
//
//  Created by Victor Belov on 27/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import UIKit

class OpenHABInfoViewController: UITableViewController {
    @IBOutlet private var appVersionLabel: UILabel!
    @IBOutlet private var openHABVersionLabel: UILabel!
    @IBOutlet private var openHABUUIDLabel: UILabel!
    @IBOutlet private var openHABSecretLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let versionBuildString = "\(appVersionString ?? "") (\(appBuildString ?? ""))"
        appVersionLabel.text = versionBuildString
        openHABVersionLabel.text = "-"
        openHABUUIDLabel.text = "-"
        openHABSecretLabel.text = "-"
    }
}
