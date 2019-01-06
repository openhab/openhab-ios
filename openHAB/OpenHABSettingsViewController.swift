//
//  OpenHABSettingsViewController.swift
//  openHAB
//
//  Created by Victor Belov on 12/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

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

    var settingsLocalUrl = ""
    var settingsRemoteUrl = ""
    var settingsUsername = ""
    var settingsPassword = ""
    var settingsIgnoreSSL = false
    var settingsDemomode = false
    var settingsIdleOff = false

    override init(style: UITableView.Style) {
        super.init(style: style)

        // Custom initialization

    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("OpenHABSettingsViewController viewDidLoad")
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
        print("Cancel button pressed")
    }

    @objc func saveButtonPressed(_ sender: Any?) {
        // TODO: Make a check if any of the preferences has changed
        print("Save button pressed")
        updateSettings()
        saveSettings()
        appData()?.rootViewController?.pageUrl = ""
        navigationController?.popToRootViewController(animated: true)
    }

    @objc func demomodeSwitchChange(_ sender: Any?) {
        if (demomodeSwitch?.isOn)! {
            print("Demo is ON")
            disableConnectionSettings()
        } else {
            print("Demo is OFF")
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
            ret = 6
        default:
            ret = 6
        }
        return ret
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        settingsTableView.deselectRow(at: indexPath, animated: true)
        print(String(format: "Row selected %ld %ld", indexPath.section, indexPath.row))
        if indexPath.section == 1 && indexPath.row == 2 {
            print("Clearing image cache")
            let imageCache = SDImageCache.shared()
            imageCache?.clearMemory()
            imageCache?.clearDisk()
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
        print("OpenHABSettingsViewController prepareForSegue")
        if segue.identifier == "showSelectSitemap" {
            print("OpenHABSettingsViewController showSelectSitemap")
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
    }

    func updateSettings() {
        settingsLocalUrl = localUrlTextField?.text ?? ""
        settingsRemoteUrl = remoteUrlTextField?.text ?? ""
        settingsUsername = usernameTextField?.text ?? ""
        settingsPassword = passwordTextField?.text ?? ""
        settingsIgnoreSSL = ignoreSSLSwitch?.isOn ?? false
        settingsDemomode = demomodeSwitch?.isOn ?? false
        settingsIdleOff = idleOffSwitch?.isOn ?? false
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
    }

    func appData() -> OpenHABDataObject? {
        let theDelegate = UIApplication.shared.delegate as? OpenHABAppDataDelegate?
        return theDelegate??.appData()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
