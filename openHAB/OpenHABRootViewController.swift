// Copyright (c) 2010-2024 Contributors to the openHAB project
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

struct CommandItem: CommItem {
    var link: String
}

class OpenHABRootViewController: UIViewController {
    var hamburgerButton: DynamicButton!
    var currentView: OpenHABViewController!
    var isDemoMode = false

    private lazy var webViewController: OpenHABWebViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        var viewController = storyboard.instantiateViewController(withIdentifier: "OpenHABWebViewController") as! OpenHABWebViewController
        return viewController
    }()

    private lazy var sitemapViewController: OpenHABSitemapViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        var viewController = storyboard.instantiateViewController(withIdentifier: "OpenHABPageViewController") as! OpenHABSitemapViewController
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
            Preferences.demomode = true
        }
        // setup accessibilityIdentifiers for UITest
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "HamburgerButton"
        #endif
        // save this so we know if its changed later
        isDemoMode = Preferences.demomode
        switchToSavedView()

        // ready for push notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleApnsMessage(notification:)), name: .apnsReceived, object: nil)
        // check if we were launched with a notification
        if let userInfo = appData?.lastNotificationInfo {
            handleNotification(userInfo)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        os_log("OpenHABRootController viewWillAppear", log: .viewCycle, type: .info)
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        // if we have turned demo mode off/on, reset view
        if isDemoMode != Preferences.demomode {
            switchToSavedView()
            isDemoMode = Preferences.demomode
        }
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
        if let menu = SideMenuManager.default.rightMenuNavigationController {
            let drawer = menu.viewControllers.first as? OpenHABDrawerTableViewController
            drawer?.delegate = self
        }
    }

    @objc
    func rightDrawerButtonPress(_ sender: Any?) {
        showSideMenu()
    }

    @objc
    func handleApsRegistration(_ note: Notification?) {
        os_log("handleApsRegistration", log: .notifications, type: .info)
        let theData = note?.userInfo
        if theData != nil {
            let prefsURL = Preferences.remoteUrl
            if prefsURL.contains("openhab.org") {
                guard let deviceId = theData?["deviceId"] as? String, let deviceToken = theData?["deviceToken"] as? String, let deviceName = theData?["deviceName"] as? String else { return }
                os_log("Registering notifications with %{public}@", log: .notifications, type: .info, prefsURL)
                NetworkConnection.register(prefsURL: prefsURL, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName) { response in
                    switch response.result {
                    case .success:
                        os_log("my.openHAB registration sent", log: .notifications, type: .info)
                    case let .failure(error):
                        os_log("my.openHAB registration failed %{public}@ %d", log: .notifications, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
                    }
                }
            }
        }
    }

    @objc func handleApnsMessage(notification: Notification) {
        // actionIdentifier is the result of a action button being pressed
        if let userInfo = notification.userInfo {
            handleNotification(userInfo)
        }
    }

    private func handleNotification(_ userInfo: [AnyHashable: Any]) {
        // actionIdentifier is the result of a action button being pressed
        // if not actionIdentifier, then the notification was clicked, so use "on-click" if there
        if let action = userInfo["actionIdentifier"] as? String ?? userInfo["on-click"] as? String {
            let cmd = action.split(separator: ":").dropFirst().joined(separator: ":")
            if action.hasPrefix("ui") {
                uiCommandAction(cmd)
            } else if action.hasPrefix("command") {
                sendCommandAction(cmd)
            } else if action.hasPrefix("http") {
                httpCommandAction(action)
            }
        }
    }

    private func uiCommandAction(_ command: String) {
        os_log("navigateCommandAction:  %{public}@", log: .notifications, type: .info, command)
        let pattern = "^(/basicui/app\\?.*|/.*|.*)$"

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = command as NSString
            let results = regex.matches(in: command, options: [], range: NSRange(location: 0, length: nsString.length))

            if let match = results.first {
                let pathRange = match.range(at: 1)
                let path = nsString.substring(with: pathRange)
                os_log("navigateCommandAction path:  %{public}@", log: .notifications, type: .info, path)
                if currentView != webViewController {
                    switchView(target: .webview)
                }
                if path.starts(with: "/basicui/app?") {
                    // TODO: this is a sitemap, we should use the native renderer
                    // temp hack right now to just use a webview
                    webViewController.loadWebView(force: true, path: path)
                } else if path.starts(with: "/") {
                    // have the webview load this path itself
                    webViewController.loadWebView(force: true, path: path)
                } else {
                    // have the mainUI handle the navigation
                    webViewController.navigateCommand(path)
                }
            }
        } catch {
            os_log("Invalid regex: %{public}@", log: .notifications, type: .error, error.localizedDescription)
        }
    }

    private func sendCommandAction(_ action: String) {
        let components = action.split(separator: ":")
        if components.count == 2 {
            let itemName = String(components[0])
            let itemCommand = String(components[1])
            let client = HTTPClient(username: Preferences.username, password: Preferences.username)
            client.doPost(baseURLs: [Preferences.localUrl, Preferences.remoteUrl], path: "/rest/items/\(itemName)", body: itemCommand) { data, _, error in
                if let error {
                    os_log("Could not send data %{public}@", log: .default, type: .error, error.localizedDescription)
                } else {
                    os_log("Request succeeded", log: .default, type: .info)
                    if let data {
                        os_log("Data: %{public}@", log: .default, type: .debug, String(data: data, encoding: .utf8) ?? "")
                    }
                }
            }
        }
    }

    private func httpCommandAction(_ command: String) {
        if let url = URL(string: command) {
            let vc = SFSafariViewController(url: url)
            present(vc, animated: true)
        }
    }

    func showSideMenu() {
        os_log("OpenHABRootViewController showSideMenu", log: .viewCycle, type: .info)
        if let menu = SideMenuManager.default.rightMenuNavigationController {
            // don't try and push an already visible menu less you crash the app
            dismiss(animated: false) {
                var topMostViewController: UIViewController? = if #available(iOS 13, *) {
                    UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.last { $0.isKeyWindow }?.rootViewController
                } else {
                    UIApplication.shared.keyWindow?.rootViewController
                }
                while let presentedViewController = topMostViewController?.presentedViewController {
                    topMostViewController = presentedViewController
                }
                topMostViewController?.present(menu, animated: true)
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
            appData?.currentView = target
            // Don't save our view in demo mode
            if !Preferences.demomode {
                Preferences.defaultView = currentView.viewName()
            }
        } else {
            // if we hit the menu item again while on the view, trigger a reload
            currentView.reloadView()
        }
        // make sure we reset any views that may be pushed
        currentView.navigationController?.popToRootViewController(animated: true)
    }

    private func switchToSavedView() {
        if Preferences.demomode {
            switchView(target: .sitemap)
        } else {
            os_log("OpenHABRootViewController switchToSavedView %@", log: .viewCycle, type: .info, Preferences.defaultView == "sitemap" ? "sitemap" : "web")
            switchView(target: Preferences.defaultView == "sitemap" ? .sitemap : .webview)
        }
    }
}

// MARK: - UISideMenuNavigationControllerDelegate

extension OpenHABRootViewController: SideMenuNavigationControllerDelegate {
    func sideMenuWillAppear(menu: SideMenuNavigationController, animated: Bool) {
        os_log("OpenHABRootViewController sideMenuWillAppear", log: .viewCycle, type: .info)
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
                navigationController?.pushViewController(newViewController, animated: true)
            }
        case .notifications:
            if navigationController?.visibleViewController is OpenHABNotificationsViewController {
                os_log("Notifications are already open", log: .notifications, type: .info)
            } else {
                if let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABNotificationsViewController") as? OpenHABNotificationsViewController {
                    navigationController?.pushViewController(newViewController, animated: true)
                }
            }
        case .webview:
            switchView(target: to)
        }
    }
}
