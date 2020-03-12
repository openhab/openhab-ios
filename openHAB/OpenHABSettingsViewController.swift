// Copyright (c) 2010-2020 Contributors to the openHAB project
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
import os.log
import UIKit

class OpenHABSettingsViewController: UITableViewController, UITextFieldDelegate {
    var settingsLocalUrl = ""
    var settingsRemoteUrl = ""
    var settingsUsername = ""
    var settingsPassword = ""
    var settingsAlwaysSendCreds = false
    var settingsIgnoreSSL = false
    var settingsDemomode = false
    var settingsIdleOff = false
    var settingsIconType: IconType = .png
    var settingsRealTimeSliders = false

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    @IBOutlet private var settingsTableView: UITableView!
    @IBOutlet private var demomodeSwitch: UISwitch!
    @IBOutlet private var passwordTextField: UITextField!
    @IBOutlet private var usernameTextField: UITextField!
    @IBOutlet private var remoteUrlTextField: UITextField!
    @IBOutlet private var localUrlTextField: UITextField!
    @IBOutlet private var idleOffSwitch: UISwitch!
    @IBOutlet private var ignoreSSLSwitch: UISwitch!
    @IBOutlet private var iconSegmentedControl: UISegmentedControl!
    @IBOutlet private var alwaysSendCredsSwitch: UISwitch!
    @IBOutlet private var realTimeSlidersSwitch: UISwitch!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("OpenHABSettingsViewController viewDidLoad", log: .viewCycle, type: .info)
        navigationItem.hidesBackButton = true
        let leftBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(OpenHABSettingsViewController.cancelButtonPressed(_:)))
        let rightBarButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(OpenHABSettingsViewController.saveButtonPressed(_:)))
        navigationItem.leftBarButtonItem = leftBarButton
        navigationItem.rightBarButtonItem = rightBarButton
        loadSettings()
        updateSettingsUi()
        localUrlTextField?.delegate = self
        remoteUrlTextField?.delegate = self
        usernameTextField?.delegate = self
        passwordTextField?.delegate = self
        demomodeSwitch?.addTarget(self, action: #selector(OpenHABSettingsViewController.demomodeSwitchChange(_:)), for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            settingsTableView.deselectRow(at: indexPathForSelectedRow, animated: true)
        }
    }

    // This is to automatically hide keyboard on done/enter pressing
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    @objc
    func cancelButtonPressed(_ sender: Any?) {
        navigationController?.popViewController(animated: true)
        os_log("Cancel button pressed", log: .viewCycle, type: .info)
    }

    @objc
    func saveButtonPressed(_ sender: Any?) {
        // TODO: Make a check if any of the preferences has changed
        os_log("Save button pressed", log: .viewCycle, type: .info)

        updateSettings()
        saveSettings()
        appData?.rootViewController?.pageUrl = ""
        navigationController?.popToRootViewController(animated: true)
    }

    @objc
    func demomodeSwitchChange(_ sender: Any?) {
        if demomodeSwitch!.isOn {
            os_log("Demo is ON", log: .viewCycle, type: .info)
            disableConnectionSettings()
        } else {
            os_log("Demo is OFF", log: .viewCycle, type: .info)
            enableConnectionSettings()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var ret: Int
        switch section {
        case 0:
            if demomodeSwitch!.isOn {
                ret = 1
            } else {
                ret = 6
            }
        case 1:
            ret = 9
        default:
            ret = 9
        }
        return ret
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        settingsTableView.deselectRow(at: indexPath, animated: true)
        os_log("Row selected %d %d", log: .notifications, type: .info, indexPath.section, indexPath.row)
        if indexPath.section == 1, indexPath.row == 2 {
            os_log("Clearing image cache", log: .viewCycle, type: .info)
        }
    }

    func enableConnectionSettings() {
        settingsTableView.reloadData()
    }

    func disableConnectionSettings() {
        settingsTableView.reloadData()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        os_log("OpenHABSettingsViewController prepareForSegue", log: .viewCycle, type: .info)

        if segue.identifier == "showSelectSitemap" {
            os_log("OpenHABSettingsViewController showSelectSitemap", log: .viewCycle, type: .info)
            let dest = segue.destination as! OpenHABDrawerTableViewController
            dest.drawerTableType = .withoutStandardMenuEntries
            dest.openHABRootUrl = appData?.openHABRootUrl ?? ""
            dest.delegate = appData?.rootViewController
            updateSettings()
            saveSettings()
        }
    }

    func updateSettingsUi() {
        localUrlTextField?.text = settingsLocalUrl
        remoteUrlTextField?.text = settingsRemoteUrl
        usernameTextField?.text = settingsUsername
        passwordTextField?.text = settingsPassword
        alwaysSendCredsSwitch?.isOn = settingsAlwaysSendCreds
        ignoreSSLSwitch?.isOn = settingsIgnoreSSL
        demomodeSwitch?.isOn = settingsDemomode
        idleOffSwitch?.isOn = settingsIdleOff
        realTimeSlidersSwitch?.isOn = settingsRealTimeSliders
        iconSegmentedControl?.selectedSegmentIndex = settingsIconType.rawValue
        if settingsDemomode == true {
            disableConnectionSettings()
        } else {
            enableConnectionSettings()
        }
    }

    func loadSettings() {
        settingsLocalUrl = Preferences.localUrl
        settingsRemoteUrl = Preferences.remoteUrl
        settingsUsername = Preferences.username
        settingsPassword = Preferences.password
        settingsAlwaysSendCreds = Preferences.alwaysSendCreds
        settingsIgnoreSSL = Preferences.ignoreSSL
        settingsDemomode = Preferences.demomode
        settingsIdleOff = Preferences.idleOff
        settingsRealTimeSliders = Preferences.realTimeSliders
        let rawSettingsIconType = Preferences.iconType
        settingsIconType = IconType(rawValue: rawSettingsIconType) ?? .png
    }

    func updateSettings() {
        settingsLocalUrl = localUrlTextField?.text ?? ""
        settingsRemoteUrl = remoteUrlTextField?.text ?? ""
        settingsUsername = usernameTextField?.text ?? ""
        settingsPassword = passwordTextField?.text ?? ""
        settingsAlwaysSendCreds = alwaysSendCredsSwitch?.isOn ?? false
        settingsIgnoreSSL = ignoreSSLSwitch?.isOn ?? false
        NetworkConnection.shared.serverCertificateManager.ignoreSSL = settingsIgnoreSSL
        settingsDemomode = demomodeSwitch?.isOn ?? false
        settingsIdleOff = idleOffSwitch?.isOn ?? false
        settingsRealTimeSliders = realTimeSlidersSwitch?.isOn ?? false
        settingsIconType = IconType(rawValue: iconSegmentedControl.selectedSegmentIndex) ?? .png
    }

    func saveSettings() {
        Preferences.localUrl = settingsLocalUrl
        Preferences.remoteUrl = settingsRemoteUrl
        Preferences.username = settingsUsername
        Preferences.password = settingsPassword
        Preferences.alwaysSendCreds = settingsAlwaysSendCreds
        Preferences.ignoreSSL = settingsIgnoreSSL
        Preferences.demomode = settingsDemomode
        Preferences.idleOff = settingsIdleOff
        Preferences.realTimeSliders = settingsRealTimeSliders
        Preferences.iconType = settingsIconType.rawValue

        WatchMessageService.singleton.syncPreferencesToWatch()
    }
}
