//
//  OpenHABSettingsViewController.swift
//  openHAB
//
//  Created by Victor Belov on 12/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import os.log
import SDWebImage
import UIKit

class OpenHABSettingsViewController: UITableViewController, OpenHABAppDataDelegate, UITextFieldDelegate {
    @IBOutlet var settingsTableView: UITableView!

    @IBOutlet weak var demomodeSwitch: UISwitch!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var remoteUrlTextField: UITextField!
    @IBOutlet weak var localUrlTextField: UITextField!
    @IBOutlet weak var idleOffSwitch: UISwitch!
    @IBOutlet weak var ignoreSSLSwitch: UISwitch!
    @IBOutlet weak var iconSegmentedControl: UISegmentedControl!

    var settingsLocalUrl = ""
    var settingsRemoteUrl = ""
    var settingsUsername = ""
    var settingsPassword = ""
    var settingsIgnoreSSL = false
    var settingsDemomode = false
    var settingsIdleOff = false
    var settingsIconType = 0

    override init(style: UITableView.Style) {
        super.init(style: style)
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

    @objc func cancelButtonPressed(_ sender: Any?) {
        navigationController?.popViewController(animated: true)
        os_log("Cancel button pressed", log: .viewCycle, type: .info)

    }

    @objc func saveButtonPressed(_ sender: Any?) {
        // TODO: Make a check if any of the preferences has changed
        os_log("Save button pressed", log: .viewCycle, type: .info)

        updateSettings()
        saveSettings()
        appData?.rootViewController?.pageUrl = ""
        navigationController?.popToRootViewController(animated: true)
    }

    @objc func demomodeSwitchChange(_ sender: Any?) {
        if (demomodeSwitch?.isOn)! {
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
            if (demomodeSwitch?.isOn)! {
                ret = 1
            } else {
                ret = 5
            }
        case 1:
            ret = 7
        default:
            ret = 7
        }
        return ret
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        settingsTableView.deselectRow(at: indexPath, animated: true)
        os_log("Row selected %d %d", log: .notifications, type: .info, indexPath.section, indexPath.row)
        if indexPath.section == 1 && indexPath.row == 2 {
            os_log("Clearing image cache", log: .viewCycle, type: .info)
            let imageCache = SDImageCache.shared
            imageCache.clearMemory()
            imageCache.clearDisk()
        }
    }

    func enableConnectionSettings() {
        settingsTableView.reloadData()
    }

    func disableConnectionSettings() {
        settingsTableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        os_log("OpenHABSettingsViewController prepareForSegue", log: .viewCycle, type: .info)

        if segue.identifier == "showSelectSitemap" {
            os_log("OpenHABSettingsViewController showSelectSitemap", log: .viewCycle, type: .info)

            updateSettings()
            saveSettings()
        }
    }

    func updateSettingsUi() {
        localUrlTextField?.text = settingsLocalUrl
        remoteUrlTextField?.text = settingsRemoteUrl
        usernameTextField?.text = settingsUsername
        passwordTextField?.text = settingsPassword
        ignoreSSLSwitch?.isOn = settingsIgnoreSSL
        demomodeSwitch?.isOn = settingsDemomode
        idleOffSwitch?.isOn = settingsIdleOff
        iconSegmentedControl?.selectedSegmentIndex = settingsIconType
        if settingsDemomode == true {
            disableConnectionSettings()
        } else {
            enableConnectionSettings()
        }
    }

    func loadSettings() {
        let prefs = UserDefaults.standard
        settingsLocalUrl = prefs.string(forKey: "localUrl") ?? ""
        settingsRemoteUrl = prefs.string(forKey: "remoteUrl") ?? ""
        settingsUsername = prefs.string(forKey: "username") ?? ""
        settingsPassword = prefs.string(forKey: "password") ?? ""
        settingsIgnoreSSL = prefs.bool(forKey: "ignoreSSL")
        settingsDemomode = prefs.bool(forKey: "demomode")
        settingsIdleOff = prefs.bool(forKey: "ildeOff")
        settingsIconType = prefs.integer(forKey: "iconType")
        
        sendSettingsToWatch()
    }

    func updateSettings() {
        settingsLocalUrl = localUrlTextField?.text ?? ""
        settingsRemoteUrl = remoteUrlTextField?.text ?? ""
        settingsUsername = usernameTextField?.text ?? ""
        settingsPassword = passwordTextField?.text ?? ""
        settingsIgnoreSSL = ignoreSSLSwitch?.isOn ?? false
        settingsDemomode = demomodeSwitch?.isOn ?? false
        settingsIdleOff = idleOffSwitch?.isOn ?? false
        settingsIconType = iconSegmentedControl.selectedSegmentIndex
    }

    func saveSettings() {
        let prefs = UserDefaults.standard
        prefs.setValue(settingsLocalUrl, forKey: "localUrl")
        prefs.setValue(settingsRemoteUrl, forKey: "remoteUrl")
        prefs.setValue(settingsUsername, forKey: "username")
        prefs.setValue(settingsPassword, forKey: "password")
        prefs.set(settingsIgnoreSSL, forKey: "ignoreSSL")
        prefs.set(settingsDemomode, forKey: "demomode")
        prefs.set(settingsIdleOff, forKey: "idleOff")
        prefs.set(settingsIconType, forKey: "iconType")
        
        sendSettingsToWatch()
    }

    func sendSettingsToWatch() {
        let prefs = UserDefaults.standard
        
        WatchService.singleton.sendToWatch(
            prefs.string(forKey: "localUrl") ?? "",
            remoteUrl: prefs.string(forKey: "remoteUrl") ?? "",
            username: prefs.string(forKey: "username") ?? "",
            password: prefs.string(forKey: "password") ?? "",
            sitemapName: "watch")
    }
    
    func appData() -> OpenHABDataObject? {
        let theDelegate = UIApplication.shared.delegate as? AppDelegate
        return theDelegate?.appData
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
