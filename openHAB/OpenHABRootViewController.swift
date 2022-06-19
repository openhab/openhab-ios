// Copyright (c) 2010-2022 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import DynamicButton
import FirebaseCrashlytics
import Foundation
import OpenHABCore
import os.log
import SafariServices
import SideMenu
import UIKit

enum TargetController {
    case root
    case settings
    case notifications
    case webview
}

protocol ModalHandler: AnyObject {
    func modalDismissed(to: TargetController)
}

class OpenHABRootViewController: OpenHABViewController {
    private var deviceToken = ""
    private var deviceId = ""
    private var deviceName = ""
    private var sitemapViewController: OpenHABSitemapViewController!
    private var webViewController: OpenHABWebViewController!

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("OpenHABRootViewController viewDidLoad", log: .default, type: .info)

        setupSideMenu()

        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABRootViewController.handleApsRegistration(_:)), name: NSNotification.Name("apsRegistered"), object: nil)

        if Crashlytics.crashlytics().didCrashDuringPreviousExecution(), !Preferences.sendCrashReports {
            let alertController = UIAlertController(title: NSLocalizedString("crash_detected", comment: "").capitalized, message: NSLocalizedString("crash_reporting_info", comment: ""), preferredStyle: .alert)
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("activate", comment: ""), style: .default) { _ in
                    Preferences.sendCrashReports = true
                    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
                    Crashlytics.crashlytics().sendUnsentReports()
                }
            )
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("privacy_policy", comment: ""), style: .default) { [weak self] _ in
                    let webViewController = SFSafariViewController(url: URL.privacyPolicy)
                    webViewController.configuration.barCollapsingEnabled = true
                    self?.present(webViewController, animated: true)
                }
            )
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .default) { _ in
                    Crashlytics.crashlytics().deleteUnsentReports()
                }
            )
            present(alertController, animated: true)
        }

        sitemapViewController = storyboard!.instantiateViewController(withIdentifier: "OpenHABPageViewController") as? OpenHABSitemapViewController
        webViewController = storyboard!.instantiateViewController(withIdentifier: "OpenHABWebViewController") as? OpenHABWebViewController

        appData?.rootViewController = self
        appData?.currentViewController = self

        #if DEBUG
        // setup accessibilityIdentifiers for UITest
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "HamburgerButton"
        #endif
    }

    override func viewWillAppear(_ animated: Bool) {
        os_log("OpenHABRootController viewWillAppear", log: .viewCycle, type: .info)
        super.viewWillAppear(animated)
        if Preferences.defaultView == "sitemap" {
            setOrReloadRootViewController(vc: sitemapViewController)
        } else {
            setOrReloadRootViewController(vc: webViewController)
        }
    }

    fileprivate func setupSideMenu() {
        // Define the menus

        SideMenuManager.default.rightMenuNavigationController = storyboard!.instantiateViewController(withIdentifier: "RightMenuNavigationController") as? SideMenuNavigationController

        // Enable gestures. The left and/or right menus must be set up above for these to work.
        // Note that these continue to work on the Navigation Controller independent of the View Controller it displays!
        SideMenuManager.default.addPanGestureToPresent(toView: navigationController!.navigationBar)
        SideMenuManager.default.addScreenEdgePanGesturesToPresent(toView: navigationController!.view, forMenu: .right)

        let presentationStyle: SideMenuPresentationStyle = .viewSlideOutMenuIn
        presentationStyle.presentingEndAlpha = 1
        presentationStyle.onTopShadowOpacity = 0.5
        var settings = SideMenuSettings()
        settings.presentationStyle = presentationStyle
        settings.statusBarEndAlpha = 0

        SideMenuManager.default.rightMenuNavigationController?.settings = settings
        guard let menu = SideMenuManager.default.rightMenuNavigationController else { return }
        let drawer = menu.viewControllers.first as? OpenHABDrawerTableViewController
        drawer?.delegate = self
    }

    @objc
    func setDrawerDefaultsAndPresent(presentMenu: Bool) {
        guard let menu = SideMenuManager.default.rightMenuNavigationController else { return }
        let drawer = menu.viewControllers.first as? OpenHABDrawerTableViewController
        drawer?.delegate = self
        // drawer?.drawerTableType = .withStandardMenuEntries
        if presentMenu {
            present(menu, animated: true)
        }
    }

    @objc
    func rightDrawerButtonPress(_ sender: Any?) {
        guard let menu = SideMenuManager.default.rightMenuNavigationController else { return }
        present(menu, animated: true)
    }

    @objc
    func handleApsRegistration(_ note: Notification?) {
        os_log("handleApsRegistration", log: .notifications, type: .info)
        let theData = note?.userInfo
        if theData != nil {
            deviceId = theData?["deviceId"] as? String ?? ""
            deviceToken = theData?["deviceToken"] as? String ?? ""
            deviceName = theData?["deviceName"] as? String ?? ""
            doRegisterAps()
        }
    }

    func doRegisterAps() {
        let prefsURL = Preferences.remoteUrl
        if prefsURL.contains("openhab.org") {
            if !deviceId.isEmpty, !deviceToken.isEmpty, !deviceName.isEmpty {
                os_log("Registering notifications with %{PUBLIC}@", log: .notifications, type: .info, prefsURL)
                NetworkConnection.register(prefsURL: prefsURL, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName) { response in
                    switch response.result {
                    case .success:
                        os_log("my.openHAB registration sent", log: .notifications, type: .info)
                    case let .failure(error):
                        os_log("my.openHAB registration failed %{PUBLIC}@ %d", log: .notifications, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
                    }
                }
            }
        }
    }

    func setOrReloadRootViewController(vc: OpenHABViewController) {
        if appData?.currentViewController != vc {
            appData?.currentViewController?.navigationController?.setViewControllers([vc], animated: true)
            appData?.currentViewController = vc
            Preferences.defaultView = vc.viewName()
        } else {
            appData?.currentViewController?.reloadView()
        }
    }

    func pushViewController(vc: UIViewController) {
        appData?.currentViewController?.navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UISideMenuNavigationControllerDelegate

extension OpenHABRootViewController: SideMenuNavigationControllerDelegate {
    func sideMenuWillAppear(menu: SideMenuNavigationController, animated: Bool) {
        os_log("OpenHABRootViewController sideMenuWillAppear", log: .notifications, type: .info)
    }
}

// MARK: - ModalHandler

extension OpenHABRootViewController: ModalHandler {
    func modalDismissed(to: TargetController) {
        switch to {
        case .root:
            setOrReloadRootViewController(vc: sitemapViewController)
        case .settings:
            if let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABSettingsViewController") as? OpenHABSettingsViewController {
                pushViewController(vc: newViewController)
            }
        case .notifications:
            if appData?.currentViewController?.navigationController?.visibleViewController is OpenHABNotificationsViewController {
                os_log("Notifications are already open", log: .notifications, type: .info)
            } else {
                if let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABNotificationsViewController") as? OpenHABNotificationsViewController {
                    pushViewController(vc: newViewController)
                }
            }
        case .webview:
            setOrReloadRootViewController(vc: webViewController)
        }
    }
}
