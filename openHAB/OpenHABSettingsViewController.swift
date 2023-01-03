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

import FirebaseCrashlytics
import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import UIKit
import WebKit

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
    var settingsSendCrashReports = false
    var settingsSortSitemapsBy: SortSitemapsOrder = .label
    var settingsDefaultMainUIPath = ""

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
    @IBOutlet private var sendCrashReportsSwitch: UISwitch!
    @IBOutlet private var sendCrashReportsDummy: UIButton!
    @IBOutlet private var sortSitemapsBy: UISegmentedControl!
    @IBOutlet private var useCurrentMainUIPathButton: UIButton!
    @IBOutlet private var defaultMainUIPathTextField: UITextField!
    @IBOutlet private var appVersionLabel: UILabel!

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
        defaultMainUIPathTextField.delegate = self
        demomodeSwitch?.addTarget(self, action: #selector(OpenHABSettingsViewController.demomodeSwitchChange(_:)), for: .valueChanged)
        sendCrashReportsDummy.addTarget(self, action: #selector(crashReportingDummyPressed(_:)), for: .touchUpInside)
        useCurrentMainUIPathButton?.addTarget(self, action: #selector(currentMainUIPathButtonPressed(_:)), for: .touchUpInside)
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
    private func cancelButtonPressed(_ sender: Any?) {
        navigationController?.popViewController(animated: true)
        os_log("Cancel button pressed", log: .viewCycle, type: .info)
    }

    @objc
    private func saveButtonPressed(_ sender: Any?) {
        // TODO: Make a check if any of the preferences has changed
        os_log("Save button pressed", log: .viewCycle, type: .info)

        updateSettings()
        saveSettings()
        appData?.sitemapViewController?.pageUrl = ""
        NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
        navigationController?.popToRootViewController(animated: true)
    }

    @objc
    private func demomodeSwitchChange(_ sender: Any?) {
        if demomodeSwitch!.isOn {
            os_log("Demo is ON", log: .viewCycle, type: .info)
            disableConnectionSettings()
        } else {
            os_log("Demo is OFF", log: .viewCycle, type: .info)
            enableConnectionSettings()
        }
    }

    @objc
    private func privacyButtonPressed(_ sender: Any?) {
        let webViewController = SFSafariViewController(url: URL.privacyPolicy)
        webViewController.configuration.barCollapsingEnabled = true

        present(webViewController, animated: true)
    }

    @objc
    private func crashReportingDummyPressed(_ sender: Any?) {
        if sendCrashReportsSwitch.isOn {
            sendCrashReportsSwitch.setOn(!sendCrashReportsSwitch.isOn, animated: true)
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        } else {
            let alertController = UIAlertController(title: NSLocalizedString("crash_reporting", comment: ""), message: NSLocalizedString("crash_reporting_info", comment: ""), preferredStyle: .actionSheet)
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("activate", comment: ""), style: .default) { [weak self] _ in
                    self?.sendCrashReportsSwitch.setOn(true, animated: true)
                    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
                }
            )
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("privacy_policy", comment: ""), style: .default) { [weak self] _ in
                    self?.privacyButtonPressed(nil)
                }
            )
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .default)
            )

            if let popOver = alertController.popoverPresentationController {
                popOver.sourceView = sendCrashReportsSwitch
                popOver.sourceRect = sendCrashReportsSwitch.bounds
            }
            present(alertController, animated: true)
        }
    }

    @objc
    private func currentMainUIPathButtonPressed(_ sender: Any?) {
        promptForDefaultWebView()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // hide connection options when in demo mode
        if section == 0, demomodeSwitch!.isOn {
            return 1
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        settingsTableView.deselectRow(at: indexPath, animated: true)
        os_log("Row selected %d %d", log: .notifications, type: .info, indexPath.section, indexPath.row)
        switch tableView.cellForRow(at: indexPath)?.tag {
        case 888:
            privacyButtonPressed(nil)
        case 998:
            let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
            let date = Date(timeIntervalSince1970: 0)
            WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date, completionHandler: {})
            alertCacheCleared()
        case 999:
            os_log("Clearing image cache", log: .viewCycle, type: .info)
            KingfisherManager.shared.cache.clearMemoryCache()
            KingfisherManager.shared.cache.clearDiskCache()
            KingfisherManager.shared.cache.cleanExpiredDiskCache()
            alertCacheCleared()
        default: break
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("openhab_connection", comment: "")
        case 1:
            return NSLocalizedString("application_settings", comment: "")
        case 2:
            return NSLocalizedString("mainui_settings", comment: "")
        case 3:
            return NSLocalizedString("sitemap_settings", comment: "")
        case 4:
            return NSLocalizedString("about_settings", comment: "")
        default:
            return ""
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func enableConnectionSettings() {
        settingsTableView.reloadData()
    }

    func disableConnectionSettings() {
        settingsTableView.reloadData()
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
        sendCrashReportsSwitch?.isOn = settingsSendCrashReports
        iconSegmentedControl?.selectedSegmentIndex = settingsIconType.rawValue
        sortSitemapsBy?.selectedSegmentIndex = settingsSortSitemapsBy.rawValue
        defaultMainUIPathTextField?.text = settingsDefaultMainUIPath
        if settingsDemomode == true {
            disableConnectionSettings()
        } else {
            enableConnectionSettings()
        }

        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        appVersionLabel?.text = "\(appVersionString ?? "") (\(appBuildString ?? ""))"
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
        settingsSendCrashReports = Preferences.sendCrashReports
        settingsIconType = IconType(rawValue: Preferences.iconType) ?? .png
        settingsSortSitemapsBy = SortSitemapsOrder(rawValue: Preferences.sortSitemapsby) ?? .label
        settingsDefaultMainUIPath = Preferences.defaultMainUIPath
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
        settingsSendCrashReports = sendCrashReportsSwitch?.isOn ?? false
        settingsIconType = IconType(rawValue: iconSegmentedControl.selectedSegmentIndex) ?? .png
        settingsSortSitemapsBy = SortSitemapsOrder(rawValue: sortSitemapsBy.selectedSegmentIndex) ?? .label
        settingsDefaultMainUIPath = defaultMainUIPathTextField?.text ?? ""
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
        Preferences.sendCrashReports = settingsSendCrashReports
        Preferences.sortSitemapsby = settingsSortSitemapsBy.rawValue
        Preferences.defaultMainUIPath = settingsDefaultMainUIPath
        WatchMessageService.singleton.syncPreferencesToWatch()
    }

    func promptForDefaultWebView() {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: NSLocalizedString("uselastpath_settings", comment: ""), message: self.appData?.currentWebViewPath ?? "/", preferredStyle: .actionSheet)
            // popover cords needed for iPad
            if let ppc = alertController.popoverPresentationController {
                ppc.sourceView = self.useCurrentMainUIPathButton as UIView
                ppc.sourceRect = (self.useCurrentMainUIPathButton as UIView).bounds
            }
            let cancel = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { (_: UIAlertAction) in
            }
            let currentPath = UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default) { (_: UIAlertAction) in
                if let path = self.appData?.currentWebViewPath {
                    self.defaultMainUIPathTextField?.text = path
                    self.settingsDefaultMainUIPath = path
                }
            }
            alertController.addAction(currentPath)
            alertController.addAction(cancel)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    func alertCacheCleared() {
        let alertController = UIAlertController(title: NSLocalizedString("cache_cleared", comment: ""), message: "", preferredStyle: .alert)
        let confirmed = UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default)
        alertController.addAction(confirmed)
        present(alertController, animated: true, completion: nil)
    }
}
