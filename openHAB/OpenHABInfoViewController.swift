// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

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
