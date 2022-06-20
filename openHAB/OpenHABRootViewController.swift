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
    case sitemap
    case settings
    case notifications
    case webview
}

protocol ModalHandler: AnyObject {
    func modalDismissed(to: TargetController)
}

class OpenHABRootViewController: UIViewController {
    private var deviceToken = ""
    private var deviceId = ""
    private var deviceName = ""
    var hamburgerButton: DynamicButton!
    var currentView: OpenHABViewController!

    private lazy var webViewController: OpenHABWebViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        var viewController = storyboard.instantiateViewController(withIdentifier: "OpenHABWebViewController") as! OpenHABWebViewController
        self.addView(viewController: viewController)
        return viewController
    }()

    private lazy var sitemapViewController: OpenHABSitemapViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        var viewController = storyboard.instantiateViewController(withIdentifier: "OpenHABPageViewController") as! OpenHABSitemapViewController
        self.addView(viewController: viewController)
        return viewController
    }()

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

        #if DEBUG
        if ProcessInfo.processInfo.environment["UITest"] != nil {
            // this is here to continue to make existing tests work, need to look at this later
            Preferences.defaultView = "sitemap"
        }
        // setup accessibilityIdentifiers for UITest
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "HamburgerButton"
        #endif

        switchView(target: Preferences.defaultView == "sitemap" ? .sitemap : .webview)
    }

    override func viewWillAppear(_ animated: Bool) {
        os_log("OpenHABRootController viewWillAppear", log: .viewCycle, type: .info)
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    fileprivate func setupSideMenu() {
        let hamburgerButtonItem: UIBarButtonItem
        if #available(iOS 13.0, *) {
            let imageConfig = UIImage.SymbolConfiguration(textStyle: .largeTitle)
            let buttonImage = UIImage(systemName: "line.horizontal.3", withConfiguration: imageConfig)
            let button = UIButton(type: .custom)
            button.setImage(buttonImage, for: .normal)
            button.addTarget(self, action: #selector(OpenHABRootViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
            hamburgerButtonItem = UIBarButtonItem(customView: button)
            hamburgerButtonItem.customView?.heightAnchor.constraint(equalToConstant: 30).isActive = true
        } else {
            hamburgerButton = DynamicButton(frame: CGRect(x: 0, y: 0, width: 31, height: 31))
            hamburgerButton.setStyle(.hamburger, animated: true)
            hamburgerButton.addTarget(self, action: #selector(OpenHABRootViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
            hamburgerButton.strokeColor = view.tintColor
            hamburgerButtonItem = UIBarButtonItem(customView: hamburgerButton)
        }
        navigationItem.setRightBarButton(hamburgerButtonItem, animated: true)

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

    private func addView(viewController: UIViewController) {
        addChild(viewController)
        view.addSubview(viewController.view)
        viewController.view.frame = view.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.didMove(toParent: self)
    }

    private func removeView(viewController: UIViewController) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }

    private func switchView(target: TargetController) {
        let targetView = target == .sitemap ? sitemapViewController : webViewController

        if currentView != targetView {
            if currentView != nil {
                removeView(viewController: currentView)
            }
            addView(viewController: targetView)
            currentView = targetView
            Preferences.defaultView = currentView.viewName()
        } else {
            // if we hit the menu item again while on the view, trigger a reload
            currentView.reloadView()
        }
    }

    func pushViewController(vc: UIViewController) {
        navigationController?.pushViewController(vc, animated: true)
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
        case .sitemap:
            switchView(target: to)
        case .settings:
            if let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABSettingsViewController") as? OpenHABSettingsViewController {
                pushViewController(vc: newViewController)
            }
        case .notifications:
            if navigationController?.visibleViewController is OpenHABNotificationsViewController {
                os_log("Notifications are already open", log: .notifications, type: .info)
            } else {
                if let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABNotificationsViewController") as? OpenHABNotificationsViewController {
                    pushViewController(vc: newViewController)
                }
            }
        case .webview:
            switchView(target: to)
        }
    }
}
